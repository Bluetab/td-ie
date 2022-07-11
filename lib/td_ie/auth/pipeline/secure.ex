defmodule TdIe.Auth.Pipeline.Secure do
  @moduledoc """
  Plug pipeline for routes requiring authentication
  """

  use Guardian.Plug.Pipeline,
    otp_app: :td_ie,
    error_handler: TdIe.Auth.ErrorHandler,
    module: TdIe.Auth.Guardian

  plug Guardian.Plug.EnsureAuthenticated, claims: %{"aud" => "truedat", "iss" => "tdauth"}
  plug Guardian.Plug.LoadResource
  plug TdIe.Auth.Plug.SessionExists
  plug TdIe.Auth.Plug.CurrentResource
end
