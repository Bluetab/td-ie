defmodule TdIeWeb.PingControllerTest do
  use TdIeWeb.ConnCase

  alias TdIeWeb.PingController

  describe "ping/2" do
    test "returns pong with 200 status" do
      conn = build_conn(:get, "/ping")
      params = %{}

      result = PingController.ping(conn, params)

      assert result.status == 200
      assert result.resp_body == "pong"
    end

    test "ignores params and returns pong" do
      conn = build_conn(:get, "/ping")
      params = %{"test" => "value", "id" => 123}

      result = PingController.ping(conn, params)

      assert result.status == 200
      assert result.resp_body == "pong"
    end

    test "works with empty params" do
      conn = build_conn(:get, "/ping")
      params = %{}

      result = PingController.ping(conn, params)

      assert result.status == 200
      assert result.resp_body == "pong"
    end

    test "works with nil params" do
      conn = build_conn(:get, "/ping")
      params = nil

      result = PingController.ping(conn, params)

      assert result.status == 200
      assert result.resp_body == "pong"
    end
  end
end
