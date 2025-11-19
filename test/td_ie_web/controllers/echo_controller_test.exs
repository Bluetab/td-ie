defmodule TdIeWeb.EchoControllerTest do
  use TdIeWeb.ConnCase

  alias TdIeWeb.EchoController

  describe "echo/2" do
    test "returns JSON encoded params with 200 status" do
      conn = build_conn(:get, "/echo")
      params = %{"message" => "hello", "id" => 123}

      result = EchoController.echo(conn, params)

      assert result.status == 200
      assert result.resp_body == Jason.encode!(params)
    end

    test "handles empty params" do
      conn = build_conn(:get, "/echo")
      params = %{}

      result = EchoController.echo(conn, params)

      assert result.status == 200
      assert result.resp_body == Jason.encode!(%{})
    end

    test "handles nested params" do
      conn = build_conn(:get, "/echo")

      params = %{
        "user" => %{"name" => "John", "age" => 30},
        "settings" => %{"theme" => "dark", "notifications" => true}
      }

      result = EchoController.echo(conn, params)

      assert result.status == 200
      assert result.resp_body == Jason.encode!(params)
    end

    test "handles params with different data types" do
      conn = build_conn(:get, "/echo")

      params = %{
        "string" => "test",
        "number" => 42,
        "float" => 3.14,
        "boolean" => true,
        "list" => [1, 2, 3],
        "null" => nil
      }

      result = EchoController.echo(conn, params)

      assert result.status == 200
      assert result.resp_body == Jason.encode!(params)
    end

    test "handles params with special characters" do
      conn = build_conn(:get, "/echo")

      params = %{
        "message" => "Hello, World! 🌍",
        "special" => "ñáéíóú",
        "symbols" => "!@#$%^&*()"
      }

      result = EchoController.echo(conn, params)

      assert result.status == 200
      assert result.resp_body == Jason.encode!(params)
    end
  end
end
