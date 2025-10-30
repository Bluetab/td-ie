defmodule TdIe.Search.StoreTest do
  use TdIe.DataCase

  alias TdIe.Ingests.IngestVersion
  alias TdIe.Search.Store

  describe "stream/1" do
    test "streams ingest versions" do
      result = Store.stream(IngestVersion)
      assert is_function(result)
    end
  end

  describe "stream/2" do
    test "streams ingest versions with ids" do
      result = Store.stream(IngestVersion, [1, 2, 3])
      assert is_function(result)
    end
  end

  describe "transaction/1" do
    test "executes transaction" do
      fun = fn -> {:ok, "result"} end
      result = Store.transaction(fun)
      assert result == {:ok, "result"}
    end
  end
end
