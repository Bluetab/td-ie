defmodule TdIeWeb.IngestLinkControllerTest do
  use TdIeWeb.ConnCase

  alias TdIeWeb.IngestLinkController

  describe "create_link/2" do
    test "returns accepted status" do
      conn = build_conn(:post, "/links")
      params = %{"ingest_id" => "123"}

      result = IngestLinkController.create_link(conn, params)

      assert result.status == 202
      assert result.resp_body == ""
    end

    test "ignores params and returns accepted" do
      conn = build_conn(:post, "/links")
      params = %{"test" => "value"}

      result = IngestLinkController.create_link(conn, params)

      assert result.status == 202
      assert result.resp_body == ""
    end

    test "works with empty params" do
      conn = build_conn(:post, "/links")
      params = %{}

      result = IngestLinkController.create_link(conn, params)

      assert result.status == 202
      assert result.resp_body == ""
    end
  end

  describe "delete/2" do
    test "handles missing current_resource" do
      conn = build_conn(:delete, "/links/123")

      assert_raise UndefinedFunctionError, fn ->
        IngestLinkController.delete(conn, %{"id" => "123"})
      end
    end
  end
end
