defmodule TimerTest do
  use ExUnit.Case

  alias Timer

  describe "time/3" do
    test "times function execution in milliseconds" do
      fun = fn -> :ok end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert time >= 0
        assert result == :ok
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert result == :ok
    end

    test "times function execution in seconds" do
      fun = fn -> :ok end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert time >= 0
        assert result == :ok
        :completed
      end

      result = Timer.time(fun, on_complete, :seconds)

      assert result == :ok
    end

    test "handles function that returns value" do
      fun = fn -> "test_result" end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert result == "test_result"
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert result == "test_result"
    end

    test "handles function that raises exception" do
      fun = fn -> raise "Test error" end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert result == %RuntimeError{message: "Test error"}
        :completed
      end

      assert_raise RuntimeError, "Test error", fn ->
        Timer.time(fun, on_complete, :millis)
      end
    end

    test "handles on_complete function that raises" do
      fun = fn -> :ok end
      on_complete = fn _time, _result -> raise "Callback error" end

      result = Timer.time(fun, on_complete, :millis)

      assert result == :ok
    end

    test "handles long running function" do
      fun = fn ->
        Process.sleep(10)
        :long_result
      end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert time >= 10
        assert result == :long_result
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert result == :long_result
    end

    test "handles function that returns complex data structure" do
      fun = fn -> %{data: [1, 2, 3], status: :ok} end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert result == %{data: [1, 2, 3], status: :ok}
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert result == %{data: [1, 2, 3], status: :ok}
    end

    test "handles function that returns nil" do
      fun = fn -> nil end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert result == nil
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert result == nil
    end

    test "handles function that returns atom" do
      fun = fn -> :atom_result end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert result == :atom_result
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert result == :atom_result
    end

    test "handles function that returns list" do
      fun = fn -> [1, 2, 3, 4, 5] end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert result == [1, 2, 3, 4, 5]
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert result == [1, 2, 3, 4, 5]
    end

    test "handles function that returns tuple" do
      fun = fn -> {:ok, "success"} end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert result == {:ok, "success"}
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert result == {:ok, "success"}
    end

    test "handles function that returns binary" do
      fun = fn -> "binary_result" end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert result == "binary_result"
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert result == "binary_result"
    end

    test "handles function that returns integer" do
      fun = fn -> 42 end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert result == 42
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert result == 42
    end

    test "handles function that returns float" do
      fun = fn -> 3.14 end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert result == 3.14
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert result == 3.14
    end

    test "handles function that returns boolean" do
      fun = fn -> true end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert result == true
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert result == true
    end

    test "handles function that returns pid" do
      fun = fn -> self() end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert is_pid(result)
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert is_pid(result)
    end

    test "handles function that returns reference" do
      fun = fn -> make_ref() end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert is_reference(result)
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert is_reference(result)
    end

    test "handles function that returns port" do
      fun = fn -> Port.open({:spawn, "echo"}, [:binary]) end

      on_complete = fn time, result ->
        assert is_integer(time)
        assert is_port(result)
        :completed
      end

      result = Timer.time(fun, on_complete, :millis)

      assert is_port(result)
    end
  end
end
