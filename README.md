# SimpleMemCache

Trade memory for performance.

In-memory key-value cache with expiration-time after creation/modification/access (a.k.a. entry time-to-live and entry idle-timeout), automatic value loading and time travel support.


## Installation

  1. Add `simple_mem_cache` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:simple_mem_cache, "~> 0.1"}]
    end
    ```

  2. mix deps.get
   
    ```sh
    $ mix deps.get
    ```
  
  3. create ets table:
  
  Only ets types: set and ordered_set are supported. 
  
  To create the ets table I recommend [Eternal](https://hex.pm/packages/eternal).
  
  Code will be something like this:

    ```elixir

    defmodule MyProject do
      use Application
      
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    
    Eternal.new(SimpleMemCache, [ :named_table, :set, { :read_concurrency, true }, { :write_concurrency, true }])

    ```

## Usage

### Keep in cache for a limited time, automatically load new value after that

  - Example: scrape news and keep it 10 minutes in cache

    ```elixir
    us_news = SimpleMemCache.cache(SimpleMemCache, "news_us", 10, &Scraper.scrape_news_us/0)
    ```

  - or with anonymous function:

      ```elixir
      def news(country) do
        SimpleMemCache.cache(SimpleMemCache, "news_" <> country, 10, fn -> Scraper.scrape_news(country) end)
      end
      ```

Note about automatically new value loading:
- How long this function take to get the new value, and is this acceptable when the old value is expired? If it takes too long, consider to use an scheduler to regularly recalculate the new value and update the cache with that.


### Keep in cache for a limited time but extend life-time everytime it is accessed

  - Example: cache http response of countries rest service for at least 20 minutes 

    ```elixir
    countries_response = SimpleMemCache.cache(SimpleMemCache, "countries_response", 20, true, fn -> HTTPoison.get! "http://restcountries.eu/rest/v1/" end)
    ```

### Keep as long this process is running

  - Example: cache products retrieved from csv file
    ```elixir
    products = SimpleMemCache.cache(SimpleMemCache, "products", fn -> "products.csv" |> File.stream! |> CSV.decode |> Enum.to_list  end)
    ```
    
  - updates are still possible:

    ```elixir
    SimpleMemCache.put(SimpleMemCache, "products", new_value)
    ```

or you can force an automatically load at first access by invalidating the cached item.

### Invalidate cached item

  - Example: remove products from cache

    ```elixir
    :ok = SimpleMemCache.remove(SimpleMemCache, "products")
    ```

## IEx demo

```sh
$ iex -S mix
Interactive Elixir (1.3.2) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> f_now = fn -> DateTime.to_string(DateTime.utc_now()) end
#Function<20.52032458/0 in :erl_eval.expr/5>
iex(2)> tid = :ets.new(__MODULE__, [:set, :public, {:read_concurrency, true}, {:write_concurrency, true}])
127009
iex(3)> SimpleMemCache.put(tid, "key1", "value1")
"value1"
iex(4)> SimpleMemCache.get(tid, "key1")
{:ok, "value1"}
iex(5)> SimpleMemCache.get!(tid, "key1")
"value1"
iex(6)> SimpleMemCache.remove(tid, "key1")
"value1"
iex(7)> SimpleMemCache.get(tid, "key1")
{:not_cached, nil}
iex(8)> SimpleMemCache.get!(tid, "key1")
nil
iex(9)> IO.puts f_now.(); SimpleMemCache.put(tid, "key1", 1, "value1"); # one minute
2016-08-03 22:42:04.410133Z
"value1"
iex(10)> IO.puts f_now.(); SimpleMemCache.get(tid, "key1")
2016-08-03 22:42:36.641060Z
{:ok, "value1"}
iex(11)> IO.puts f_now.(); SimpleMemCache.get(tid, "key1")
2016-08-03 22:43:10.278992Z
{:expired, "value1"}
iex(12)> f_new_value = fn -> IO.puts "new"; "value2" end
#Function<20.52032458/0 in :erl_eval.expr/5>
iex(13)> IO.puts f_now.(); SimpleMemCache.cache(tid, "key2", 1, f_new_value); # one minute
2016-08-03 22:45:10.551159Z
new
"value2"
iex(14)> IO.puts f_now.(); SimpleMemCache.cache(tid, "key2", 1, f_new_value); # one minute
2016-08-03 22:45:16.410884Z
"value2"
iex(15)> SimpleMemCache.get(tid, "key1")
{:not_cached, nil}
iex(16)> SimpleMemCache.put(tid, "key2", "value2_changed")
"value2_changed"
iex(17)> SimpleMemCache.get(tid, "key2")
{:ok, "value2_changed"}
iex(18)> SimpleMemCache.put(tid, "key3", %{"a" => 1, "b" => {1, 2, "whatever"}})  # put whatever you want
%{"a" => 1, "b" => {1, 2, "whatever"}}
iex(19)> SimpleMemCache.get!(tid, "key3") |> Map.get("b")
{1, 2, "whatever"}
iex(20)> SimpleMemCache.stop(tid)
:ok
iex(21)> SimpleMemCache.get!(tid, "key2")
** (ArgumentError) argument error
              (stdlib) :ets.lookup(127009, "Elixir.SimpleMemCache_state")
    (simple_mem_cache) lib/simple_mem_cache.ex:139: SimpleMemCache.get_cache_state!/1
    (simple_mem_cache) lib/simple_mem_cache.ex:105: SimpleMemCache.get/3
    (simple_mem_cache) lib/simple_mem_cache.ex:111: SimpleMemCache.get!/3

```

## License

[MIT](LICENSE)
