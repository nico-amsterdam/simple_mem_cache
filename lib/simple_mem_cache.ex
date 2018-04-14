defmodule SimpleMemCache do
  @moduledoc ~S'''
  In-memory key-value cache with expiration-time after creation/modification/access,
  automatic value loading and time travel support.

  ## Prepare ETS table to be used by SimpleMemCache

  Example 1: plain ETS:

    ```elixir
    tid = :ets.new(__MODULE__, [:set,
                                 :public,
                                {:read_concurrency,  true},
                                {:write_concurrency, true}
                               ])
    ```

  Example 2: use [Eternal](https://hex.pm/packages/eternal) to create the ETS table:

    ```elixir

    defmodule MyProject do
      use Application

      def start(_type, _args) do
        import Supervisor.Spec, warn: false

        Eternal.start_link(SimpleMemCache,
                           [:set,
                            {:read_concurrency,  true},
                            {:write_concurrency, true}
                           ])

    ```

  Only ETS types: set and ordered_set are supported.

  ## Usage

  ### Keep in cache for a limited time, automatically load new value after that

    - Example: scrape news and keep it 10 minutes in cache

      ```elixir
      us_news = SimpleMemCache.cache(SimpleMemCache, "news_us", 10,
                                     &Scraper.scrape_news_us/0)
      ```

    - or with anonymous function:

        ```elixir
        def news(country) do
          SimpleMemCache.cache(SimpleMemCache, "news_" <> country, 10,
                               fn -> Scraper.scrape_news(country) end)
        end
        ```

  Note about automatically new value loading:
  - How long does this function take to get the new value, and is this acceptable when the old value is expired? If it takes too long, consider to use an scheduler to regularly recalculate the new value and update the cache with that.


  ### Keep in cache for a limited time but extend life-time everytime it is accessed

    - Example: cache http response of countries rest service for at least 20 minutes

      ```elixir
      countries_response = SimpleMemCache.cache(SimpleMemCache,
               "countries_response",
               20,
               true,
               fn -> HTTPoison.get! "http://restcountries.eu/rest/v1/" end)
      ```

  ### Keep as long as the ETS table exists

    - Example: Cache products retrieved from csv file. Not a good example, because nowadays files are stored on SSD and there will be no performance gain.

      ```elixir
      products = SimpleMemCache.cache(SimpleMemCache, "products", fn -> "products.csv"
                                                                        |> File.stream!
                                                                        |> CSV.parse_stream
                                                                        |> Enum.to_list
                                                                  end)
      ```

    - updates are still possible:

      ```elixir
      SimpleMemCache.put(SimpleMemCache, "products", new_value)
      ```

  or you can force an automatically load at first access by invalidating the cached item.

  ### Invalidate cached item

    - Example: remove products from cache

      ```elixir
      old_value = SimpleMemCache.remove(SimpleMemCache, "products")
      ```

  '''

  @typedoc "The table id (Tid) or table name"
  @type table :: number | atom

  @cache_state_key Atom.to_string(__MODULE__) <> "_state"

  @doc ~S'''
  Time travel for SimpleMemCache.

  The `f_system_time` parameter is meant for time travel support.
  You can provide a function that returns the Unix/Posix UTC time in seconds.
  Set nil to restore the normal system time.
  '''
  @spec set_system_time_function(table, (() -> integer) | nil) :: :ok
  def set_system_time_function(table, f_system_time \\ nil) do
    # in case we travel back in time,
    # we stil want to check expired entries every minute:
    next_expire_time = (f_system_time || &system_time/0).() + 60
    true = :ets.insert(table, {@cache_state_key, f_system_time, next_expire_time})
    :ok
  end

  @doc "Returns function that generates Unix/Posix UTC time in seconds."
  @spec get_system_time_function(table) :: (() -> integer)
  def get_system_time_function(table) do
    {f_system_time, _} = get_cache_state!(table)
    f_system_time
  end

  @doc ~S'''
  Cache value returned by the supplied function.

  * `table` - Name of the ETS table.
  * `key` - Key name
  * `minutes_valid` - Minutes to keep the item in cache. Default: nil - do not expire.
  * `keep_alive` - Keep the item in cache if it still accessed. It expires if it is not retrieved in `minutes_valid` minutes. Default: false
  * `f_new_value` - function that supplies the value. Enables automatic value loading. When `minutes_valid` is not nil and `keep_alive` is false, this function can be launched in a new Erlang process, and it can do this proactively up to 30 seconds before expiration.

  ## Examples

      products = SimpleMemCache.cache(SimpleMemCache, "products", 30, true,
         fn() -> File.read!(filename) end
      )

      news_page = SimpleMemCache.cache(SimpleMemCache, "news", 10, &scrape_news/0)

  '''
  @spec cache(table, Map.key(), integer | nil, boolean | nil, (() -> any)) :: any
  def cache(table, key, minutes_valid \\ nil, keep_alive \\ false, f_new_value) do
    cache_value =
      ets_get(
        table,
        {key, if(keep_alive, do: minutes_valid, else: nil), true},
        get_cache_state!(table)
      )

    case cache_value do
      {:ok, value} ->
        value

      {:expire_warning, value} ->
        spawn(fn ->
          try do
            put(table, key, minutes_valid, f_new_value.())
          rescue
            # table is deleted, ignore
            ArgumentError ->
              :error
          end
        end)

        value

      _ ->
        put(table, key, minutes_valid, f_new_value.())
    end
  end

  @doc "Create or update an item in cache."
  @spec put(table, Map.key(), integer | nil, Map.value()) :: any
  def put(table, key, minutes_valid \\ nil, value) do
    ets_put(table, {key, minutes_valid, value}, get_cache_state!(table))
  end

  @doc "Remove an item from cache. Returns the value of the removed object."
  @spec remove(table, Map.key()) :: any
  def remove(table, key) do
    ets_remove(table, {key}, get_cache_state!(table))
  end

  @doc ~S'''
  Get status and value of cached item. Status can be :ok, :expired or :not_cached

  The `minutes_keep_alive` parameter is the number of minutes to keep the item at least in cache.
  Does not shorten a previously set expiration time (use put for that). However,
  if there wasn't an expiration time it will take the new value. Default: nil - do not change the expire time.

  ## Example

      iex(1)> products = SimpleMemCache.get(SimpleMemCache, "products", 20)
      {:expired, "Fret dots"}

  '''
  @spec get(table, Map.key(), integer | nil) :: {term, any}
  def get(table, key, minutes_keep_alive \\ nil) do
    ets_get(table, {key, minutes_keep_alive, false}, get_cache_state!(table))
  end

  @doc "Get value of cached item. Nil if is not cached or when value is nil."
  @spec get!(table, Map.key(), integer | nil) :: any
  def get!(table, key, minutes_keep_alive \\ nil) do
    {_, value} = get(table, key, minutes_keep_alive)
    value
  end

  @doc "Remove expired entries. This is automatically called once a minute during SimpleMemCache usage."
  @spec remove_expired_entries(table) :: :ok
  def remove_expired_entries(table) do
    ets_remove_expired_entries(table, get_cache_state!(table))
  end

  @doc "Delete the ETS table."
  @spec stop(table) :: :ok
  def stop(table) do
    ets_delete(table)
  end

  ##
  ## The guts
  ##

  # return Unix/Posix UTC time in seconds
  defp system_time do
    :os.system_time(:seconds)
  end

  defp get_cache_state!(table) do
    key = @cache_state_key

    case :ets.lookup(table, key) do
      [{^key, f_system_time, expire_check_time}] ->
        {f_system_time || &system_time/0, expire_check_time}

      _ ->
        {&system_time/0, nil}
    end
  end

  defp set_expire_check_time(table, f_system_time, expire_check_time) do
    :ets.insert(table, {@cache_state_key, f_system_time, expire_check_time})
  end

  defp check_expired(table, now, expire_check_time) do
    if !is_nil(expire_check_time) and now >= expire_check_time do
      remove_expired_entries(table)
    end

    :ok
  end

  defp ets_put(table, {key, minutes_valid, value}, {f_system_time, expire_check_time}) do
    now = f_system_time.()
    expires = if is_nil(minutes_valid), do: nil, else: now + minutes_valid * 60
    true = :ets.insert(table, {key, value, expires, 0})
    # if we didn't check for expired items and now this item has gotten an expire time
    if is_nil(expire_check_time) and minutes_valid != nil do
      # check every minute for expired items:
      set_expire_check_time(table, f_system_time, f_system_time.() + 60)
    else
      check_expired(table, now, expire_check_time)
    end

    value
  end

  # delete the whole table
  defp ets_delete(table) do
    true = :ets.delete(table)
    :ok
  end

  defp ets_remove(table, {key}, {f_system_time, expire_check_time}) do
    removed = :ets.take(table, key)
    check_expired(table, f_system_time.(), expire_check_time)

    if length(removed) == 1 do
      [{^key, value, _, _}] = removed
      value
    else
      nil
    end
  end

  defp ets_get_status(_key, [], _minutes_keep_alive, _warn, _now) do
    {:not_cached, nil, nil}
  end

  defp ets_get_status(key, [{ckey, value, expires, _}], minutes_keep_alive, _warn, _now)
       when key == ckey and
              ((minutes_keep_alive != nil and minutes_keep_alive >= 0) or
                 (is_nil(minutes_keep_alive) and is_nil(expires))) do
    {:ok, value, expires}
  end

  defp ets_get_status(key, [{ckey, value, expires, count}], minutes_keep_alive, warn, now)
       when key == ckey and warn and count == 0 and is_nil(minutes_keep_alive) and
              expires <= now + 30 and expires > now do
    {:expire_warning, value, expires}
  end

  defp ets_get_status(key, [{ckey, value, expires, _}], _minutes_keep_alive, _warn, now)
       when key == ckey and expires != nil and expires >= now do
    {:ok, value, expires}
  end

  defp ets_get_status(key, [{ckey, old_value, expires, _}], _minutes_keep_alive, _warn, _now)
       when key == ckey do
    {:expired, old_value, expires}
  end

  defp ets_get_expire_warning(table, key, status, f_system_time) do
    # is this really The One?
    if status == :expire_warning do
      # atomic operation (4 = fourth position in tuple which hold the counter, 1 = increment one):
      warning_count = :ets.update_counter(table, key, {4, 1})

      if warning_count != 1 do
        # pitty, degrade to ok status
        :ok
      else
        # Greetings Neo, buy yourself some time

        # The client interface cache-method handles expire_warnings, therefore:
        # 1 till 30 seconds before expiring, the first caller gets a
        # warning and 30 seconds to come with a new value.
        # During the next 30 seconds other clients receive ok, with the existing cached value.
        # After 30 seconds, if no new value is set, again an expire_warning will be given.
        # The purpose of this: for very frequent requested keys,
        # don't create a give-me-new-value storm when the value expires;
        # assign the task for getting a new value to one client.
        # 3 = third position in tuple. It holds the expire time.
        :ets.update_element(table, key, {3, f_system_time.() + 60})
        :expire_warning
      end
    else
      status
    end
  end

  defp ets_get(table, {key, minutes_keep_alive, warn}, {f_system_time, expire_check_time}) do
    now = f_system_time.()

    # get
    map_value = :ets.lookup(table, key)

    # determine status
    {status, value, expires} = ets_get_status(key, map_value, minutes_keep_alive, warn, now)
    status = ets_get_expire_warning(table, key, status, f_system_time)

    # if needed, set new expire time to keep this cached item alive
    if status != :not_cached and minutes_keep_alive != nil and
         (is_nil(expires) or now + minutes_keep_alive * 60 >= expires + 30) do
      # 3 = third position in tuple. It holds the expire time.
      :ets.update_element(table, key, {3, now + minutes_keep_alive * 60 + 30})
    end

    # if we didn't check for expired items and now this item has gotten an expire time
    if status != :not_cached and is_nil(expire_check_time) and minutes_keep_alive != nil do
      # check every minute for expired items:
      set_expire_check_time(table, f_system_time, f_system_time.() + 60)
    else
      # check for expired entries
      check_expired(table, now, expire_check_time)
    end

    {status, value}
  end

  defp ets_remove_expired_entries(table, {f_system_time, _expire_check_time}) do
    now = f_system_time.()
    # remove old entries
    :ets.select_delete(table, [{{:"$1", :_, :"$2", :_}, [{:<, :"$2", now}], [true]}])

    # are there any entries with an expire time left?

    temp_entries_count =
      :ets.select_count(table, [{{:"$1", :_, :"$2", :_}, [{:"/=", :"$2", nil}], [true]}])

    next_expire_check_time = if temp_entries_count > 0, do: f_system_time.() + 60, else: nil
    set_expire_check_time(table, f_system_time, next_expire_check_time)
    :ok
  end
end
