defmodule TdIe.Auth.Pipeline.Secure do
  @moduledoc false
  use Guardian.Plug.Pipeline,
    otp_app: :td_ie,
    error_handler: TdIe.Auth.ErrorHandler,
    module: TdIe.Auth.Guardian

  plug(Guardian.Plug.EnsureAuthenticated, claims: %{"typ" => "access"})

  # Assign :current_resource to connection
  plug(TdIe.Auth.CurrentResource)
end
