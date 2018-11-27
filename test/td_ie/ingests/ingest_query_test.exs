defmodule TdIe.BusinessConceptQueryTest do
  @moduledoc """
  Test on Ingest query module
  """
  use TdIe.DataCase
  alias TdIe.Ingest.Query

  describe "business_concepts_query" do

    test "add_query_wildcard/1 Miscellaneous" do
      assert "my blah*" == Query.add_query_wildcard("my blah")

      assert "my \"blah\"" == Query.add_query_wildcard("my \"blah\"")
      assert "my blah\""   == Query.add_query_wildcard("my blah\"")
      assert "my \"blah*"  == Query.add_query_wildcard("my \"blah")

      assert "my (blah)" == Query.add_query_wildcard("my (blah)")
      assert "my blah)"  == Query.add_query_wildcard("my blah)")
      assert "my (blah*" == Query.add_query_wildcard("my (blah")

      assert "my " == Query.add_query_wildcard("my ")

    end

  end
end
