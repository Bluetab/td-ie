defmodule TdIeWeb.EchoController do
  @moduledoc false
  use TdIeWeb, :controller

  alias Jason, as: JSON

  action_fallback(TdIeWeb.FallbackController)

  def echo(conn, params) do
    send_resp(conn, 200, params |> JSON.encode!())
  end
end
