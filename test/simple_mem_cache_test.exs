defmodule SimpleMemCacheTest do
  use ExUnit.Case, async: true

  defp generate_function_with_value(x) do
    fn() -> x end
  end

  # generate time function with a fixed time.
  defp get_time_travel_function(now, plus_minutes \\ 0, plus_seconds \\ 0) do
    generate_function_with_value(now + plus_minutes * 60 + plus_seconds)
  end

  test "value is expired" do
    tid = :ets.new(__MODULE__, [:set, :public, {:read_concurrency, true}, {:write_concurrency, true}])

    now = :os.system_time(:seconds)
    f_now = get_time_travel_function(now)
    f_now_plus_10 = get_time_travel_function(now, 10)

    SimpleMemCache.set_system_time_function(tid, f_now)

    putval = SimpleMemCache.put(tid, "key1", 8, "value1")
    assert putval == "value1"

    SimpleMemCache.set_system_time_function(tid, f_now_plus_10)

    result = SimpleMemCache.get(tid, "key1")
    assert result == {:expired, "value1"}

    SimpleMemCache.stop(tid)
  end

  test "value is expired and removed" do
    tid = :ets.new(__MODULE__, [:set, :public, {:read_concurrency, true}, {:write_concurrency, true}])

    now = :os.system_time(:seconds)
    f_now = get_time_travel_function(now)
    f_now_plus_10 = get_time_travel_function(now, 10)

    SimpleMemCache.set_system_time_function(tid, f_now)

    putval = SimpleMemCache.put(tid, "key1", 8, "value1")
    assert putval == "value1"

    SimpleMemCache.set_system_time_function(tid, f_now_plus_10)

    :ok = SimpleMemCache.remove_expired_entries(tid)

    result = SimpleMemCache.get(tid, "key1")
    assert result == {:not_cached, nil}

    SimpleMemCache.stop(tid)
  end

  test "accessed before and after expired" do
    tid = :ets.new(__MODULE__, [:set, :public, {:read_concurrency, true}, {:write_concurrency, true}])

    now = :os.system_time(:seconds)
    f_now = get_time_travel_function(now)
    f_now_plus_5  = get_time_travel_function(now, 5)
    f_now_plus_10 = get_time_travel_function(now, 10)

    SimpleMemCache.set_system_time_function(tid, f_now)

    putval = SimpleMemCache.put(tid, "key1", 8, "value1")
    assert putval == "value1"

    SimpleMemCache.set_system_time_function(tid, f_now_plus_5)

    result = SimpleMemCache.get(tid, "key1")
    assert result == {:ok, "value1"}

    SimpleMemCache.set_system_time_function(tid, f_now_plus_10)

    result = SimpleMemCache.get(tid, "key1")
    assert result == {:expired, "value1"}

    SimpleMemCache.stop(tid)
  end

  test "accessed with keep alive" do
    tid = :ets.new(__MODULE__, [:set, :public, {:read_concurrency, true}, {:write_concurrency, true}])

    now = :os.system_time(:seconds)
    f_now = get_time_travel_function(now)
    f_now_plus_5  = get_time_travel_function(now, 5)
    f_now_plus_10 = get_time_travel_function(now, 10)
    f_now_plus_20 = get_time_travel_function(now, 20)

    SimpleMemCache.set_system_time_function(tid, f_now)

    putval = SimpleMemCache.put(tid, "key1", 8, "value1")
    assert putval == "value1"

    SimpleMemCache.set_system_time_function(tid, f_now_plus_5)

    result = SimpleMemCache.get(tid, "key1", 8)
    assert result == {:ok, "value1"}

    SimpleMemCache.set_system_time_function(tid, f_now_plus_10)

    result = SimpleMemCache.get(tid, "key1", 8)
    assert result == {:ok, "value1"}

    SimpleMemCache.set_system_time_function(tid, f_now_plus_20)

    # this might supprise you, but remove_expired_entries didn't run, so the expired key is awakened
    result = SimpleMemCache.get(tid, "key1", 8)
    assert result == {:ok, "value1"}

    SimpleMemCache.stop(tid)
  end

  test "accessed with keep alive. remove has run" do
    tid = :ets.new(__MODULE__, [:set, :public, {:read_concurrency, true}, {:write_concurrency, true}])

    now = :os.system_time(:seconds)
    f_now = get_time_travel_function(now)
    f_now_plus_5  = get_time_travel_function(now, 5)
    f_now_plus_10 = get_time_travel_function(now, 10)
    f_now_plus_20 = get_time_travel_function(now, 20)

    SimpleMemCache.set_system_time_function(tid, f_now)

    putval = SimpleMemCache.put(tid, "key1", 8, "value1")
    assert putval == "value1"

    SimpleMemCache.set_system_time_function(tid, f_now_plus_5)

    result = SimpleMemCache.get(tid, "key1", 8)
    assert result == {:ok, "value1"}

    SimpleMemCache.set_system_time_function(tid, f_now_plus_10)

    # nothing has expired yet
    :ok = SimpleMemCache.remove_expired_entries(tid)

    result = SimpleMemCache.get(tid, "key1", 8)
    assert result == {:ok, "value1"}

    SimpleMemCache.set_system_time_function(tid, f_now_plus_20)

    :ok = SimpleMemCache.remove_expired_entries(tid)

    result = SimpleMemCache.get(tid, "key1", 8)
    assert result == {:not_cached, nil}

    SimpleMemCache.stop(tid)
  end

  test "no expire time" do
    tid = :ets.new(__MODULE__, [:set, :public, {:read_concurrency, true}, {:write_concurrency, true}])

    now = :os.system_time(:seconds)
    f_now = get_time_travel_function(now)
    f_now_plus_10 = get_time_travel_function(now, 10)
    f_now_plus_20 = get_time_travel_function(now, 20)
    f_now_plus_30 = get_time_travel_function(now, 30)

    SimpleMemCache.set_system_time_function(tid, f_now)

    putval = SimpleMemCache.put(tid, "key1", "value1")
    assert putval == "value1"

    SimpleMemCache.set_system_time_function(tid, f_now_plus_10)

    :ok = SimpleMemCache.remove_expired_entries(tid)

    SimpleMemCache.set_system_time_function(tid, f_now_plus_20)

    result = SimpleMemCache.get(tid, "key1")
    assert result == {:ok, "value1"}

    SimpleMemCache.set_system_time_function(tid, f_now_plus_30)

    putval = SimpleMemCache.put(tid, "key1", "value2")
    assert putval == "value2"

    result = SimpleMemCache.get(tid, "key1")
    assert result == {:ok, "value2"}

    SimpleMemCache.stop(tid)
  end

  test "first no expire time" do
    tid = :ets.new(__MODULE__, [:set, :public, {:read_concurrency, true}, {:write_concurrency, true}])

    now = :os.system_time(:seconds)
    f_now = get_time_travel_function(now)
    f_now_plus_10 = get_time_travel_function(now, 10)
    f_now_plus_20 = get_time_travel_function(now, 20)
    f_now_plus_30 = get_time_travel_function(now, 30)
    f_now_plus_40 = get_time_travel_function(now, 40)

    SimpleMemCache.set_system_time_function(tid, f_now)

    putval = SimpleMemCache.put(tid, "key1", "value1")
    assert putval == "value1"

    SimpleMemCache.set_system_time_function(tid, f_now_plus_10)

    result = SimpleMemCache.get(tid, "key1", 8)
    assert result == {:ok, "value1"}

    SimpleMemCache.set_system_time_function(tid, f_now_plus_20)

    result = SimpleMemCache.get(tid, "key1")
    assert result == {:expired, "value1"}

    SimpleMemCache.set_system_time_function(tid, f_now_plus_30)

    # a new put overwrites whatever expire time there was
    putval = SimpleMemCache.put(tid, "key1", "value2")
    assert putval == "value2"

    SimpleMemCache.set_system_time_function(tid, f_now_plus_40)

    result = SimpleMemCache.get(tid, "key1")
    assert result == {:ok, "value2"}

    SimpleMemCache.stop(tid)
  end

  test "expire warning" do
    tid = :ets.new(__MODULE__, [:set, :public, {:read_concurrency, true}, {:write_concurrency, true}])

    now = :os.system_time(:seconds)
    f_now = get_time_travel_function(now)
    f_now_plus_7_plus_30_seconds = get_time_travel_function(now, 7, 30)
    f_now_plus_8_plus_31_second = get_time_travel_function(now, 8, 31)

    SimpleMemCache.set_system_time_function(tid, f_now)

    putval = SimpleMemCache.put(tid, "key1", 8, "value1")
    assert putval == "value1"

    SimpleMemCache.set_system_time_function(tid, f_now_plus_7_plus_30_seconds)

    # We should actually sleep for 30 seconds, but we don't do that in unittests.
    # After 30 seconds the process that calls the new-value function will certainly be ready.
    # Instead we let us send the pid of the spawned process and wait till it is finished.
    pid = self()

    # It's garanteed that you first get the currently cached value back
    value = SimpleMemCache.cache(
              tid,
              "key1",
              fn -> send(pid, self())
                    "value2"
              end)
    assert value == "value1"

    spawn_pid = receive do
      msg -> msg
    end

    ref = Process.monitor(spawn_pid)

    # now wait till the process is finished
    assert_receive {:DOWN, ^ref, :process, ^spawn_pid, :noproc}, 500

    SimpleMemCache.set_system_time_function(tid, f_now_plus_8_plus_31_second)
    result = SimpleMemCache.get(tid, "key1")
    assert result == {:ok, "value2"}

    SimpleMemCache.stop(tid)
  end

end
