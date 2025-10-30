defmodule TdIe.Auth.ErrorHandlerTest do
  use TdIeWeb.ConnCase

  alias TdIe.Auth.ErrorHandler

  describe "unauthorized/1" do
    test "returns a halted connection with unauthorized status" do
      conn = build_conn()
      result = ErrorHandler.unauthorized(conn)

      assert result.halted == true
      assert result.status == 401

      assert result.resp_headers |> Enum.into(%{}) |> Map.get("content-type") ==
               "application/json; charset=utf-8"
    end

    test "returns JSON response with unauthorized message" do
      conn = build_conn()
      result = ErrorHandler.unauthorized(conn)

      assert result.resp_body == Jason.encode!(%{message: "unauthorized"})
    end
  end

  describe "auth_error/3" do
    test "returns connection with unauthorized status and JSON body" do
      conn = build_conn()
      result = ErrorHandler.auth_error(conn, {:unauthorized, nil})

      assert result.status == 401

      assert result.resp_headers |> Enum.into(%{}) |> Map.get("content-type") ==
               "application/json; charset=utf-8"

      assert result.resp_body == Jason.encode!(%{message: "unauthorized"})
    end

    test "handles different error types" do
      conn = build_conn()
      result = ErrorHandler.auth_error(conn, {:forbidden, "access denied"})

      assert result.status == 401
      assert result.resp_body == Jason.encode!(%{message: "forbidden"})
    end

    test "handles error with reason" do
      conn = build_conn()
      result = ErrorHandler.auth_error(conn, {:invalid_token, "expired"})

      assert result.status == 401
      assert result.resp_body == Jason.encode!(%{message: "invalid_token"})
    end

    test "accepts opts parameter" do
      conn = build_conn()
      result = ErrorHandler.auth_error(conn, {:unauthorized, nil}, some: :option)

      assert result.status == 401
      assert result.resp_body == Jason.encode!(%{message: "unauthorized"})
    end
  end
end
