defmodule TdIe.Auth.Pipeline.Secure do
  @moduledoc false
  use Guardian.Plug.Pipeline,
    otp_app: :td_ie,
    error_handler: TdIe.Auth.ErrorHandler,
    module: TdIe.Auth.Guardian
  # If there is a session token, validate it
  #plug Guardian.Plug.VerifySession, claims: %{"typ" => "access"}
  # If there is an authorization header, validate it
  #plug Guardian.Plug.VerifyHeader, claims: %{"typ" => "access"}
  # Load the user if either of the verifications worked
  plug Guardian.Plug.EnsureAuthenticated, claims: %{"typ" => "access"}

  # Assign :current_user to connection
  plug TdIe.Auth.CurrentUser

end