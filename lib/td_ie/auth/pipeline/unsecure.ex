defmodule TdIe.Auth.Pipeline.Unsecure do
  @moduledoc false
  use Guardian.Plug.Pipeline,
    otp_app: :td_ie,
    error_handler: TdIe.Auth.ErrorHandler,
    module: TdIe.Auth.Guardian

  plug(Guardian.Plug.VerifyHeader)
  plug(Guardian.Plug.LoadResource, allow_blank: true)
end
