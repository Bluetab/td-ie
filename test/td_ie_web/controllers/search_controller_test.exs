defmodule TdIeWeb.SearchControllerTest do
  use TdIeWeb.ConnCase

  alias TdIe.Auth.Claims
  alias TdIeWeb.SearchController

  describe "reindex_all/2" do
    test "returns error when user lacks permission" do
      conn = build_conn(:post, "/search/reindex_all")
      claims = %Claims{role: "user"}
      conn = assign(conn, :current_resource, claims)

      result = SearchController.reindex_all(conn, %{})

      assert result == {:can, false}
    end

    test "handles missing current_resource" do
      conn = build_conn(:post, "/search/reindex_all")

      assert_raise UndefinedFunctionError, fn ->
        SearchController.reindex_all(conn, %{})
      end
    end
  end
end
