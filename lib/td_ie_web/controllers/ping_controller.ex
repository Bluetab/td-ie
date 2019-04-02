defmodule TdIeWeb.EchoController do
  @moduledoc false
  use TdIeWeb, :controller

  action_fallback(TdIeWeb.FallbackController)

  def echo(conn, params) do
    send_resp(conn, 200, params |> Poison.encode!())
  end
end
