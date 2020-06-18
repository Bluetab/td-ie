defmodule TdIeWeb.Authentication do
  @moduledoc """
  This module defines the functions required to
  add auth headers to requests
  """

  import Plug.Conn
  import TdIe.Factory

  alias ExUnit.Callbacks
  alias Phoenix.ConnTest
  alias TdCache.UserCache
  alias TdIe.Auth.Guardian

  def put_auth_headers(conn, jwt) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", "Bearer #{jwt}")
  end

  def create_user_auth_conn(user) do
    {:ok, jwt, full_claims} = Guardian.encode_and_sign(user, %{gids: []})
    conn = ConnTest.build_conn() |> put_auth_headers(jwt)
    {:ok, %{conn: conn, jwt: jwt, claims: full_claims}}
  end

  def create_user(opts \\ []) do
    %{id: user_id} = user = build(:user, opts)
    UserCache.put(user)
    Callbacks.on_exit(fn -> UserCache.delete(user_id) end)
    user
  end
end
