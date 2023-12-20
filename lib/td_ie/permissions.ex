defmodule TdIe.Permissions do
  @moduledoc """
  The Permissions context.
  """

  alias TdCache.Permissions
  alias TdIe.Auth.Claims

  @defaults [
    "view_approval_pending_ingests",
    "view_deprecated_ingests",
    "view_draft_ingests",
    "view_published_ingests",
    "view_rejected_ingests",
    "view_versioned_ingests"
  ]

  def get_default_permissions, do: @defaults

  def authorized?(%Claims{jti: jti}, permission, domain_id) do
    Permissions.has_permission?(jti, permission, "domain", domain_id)
  end

  def authorized?(%Claims{jti: jti}, permission) do
    Permissions.has_permission?(jti, permission)
  end
end
