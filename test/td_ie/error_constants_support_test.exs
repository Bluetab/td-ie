defmodule TdIe.ErrorConstantsSupportTest do
  use ExUnit.Case

  alias TdIe.ErrorConstantsSupport

  describe "ingest_support_errors/0" do
    test "returns ingest support errors map" do
      result = ErrorConstantsSupport.ingest_support_errors()

      assert is_map(result)
      assert Map.has_key?(result, :existing_ingest)
    end

    test "returns existing_ingest error with correct structure" do
      result = ErrorConstantsSupport.ingest_support_errors()

      existing_ingest = result[:existing_ingest]

      assert existing_ingest == %{code: "EI001", name: "ingest.error.existing.ingest"}
    end

    test "returns consistent results on multiple calls" do
      result1 = ErrorConstantsSupport.ingest_support_errors()
      result2 = ErrorConstantsSupport.ingest_support_errors()

      assert result1 == result2
    end

    test "returns immutable map" do
      result = ErrorConstantsSupport.ingest_support_errors()

      assert Map.put(result, :new_key, :new_value) != result
    end
  end
end
