defmodule TdIeWeb.PingController do
  @moduledoc """
  Checking api availability
  """
  use TdIeWeb, :controller

  action_fallback TdIeWeb.FallbackController

  def ping(conn, _params) do
    send_resp(conn, 200, "pong")
  end
end
