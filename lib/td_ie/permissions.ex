defmodule TdIe.Permissions do
  @moduledoc """
  The Permissions context.
  """

  alias TdCache.Permissions
  alias TdIe.Auth.Claims

  @defaults %{
    "view_approval_pending_ingests" => :none,
    "view_deprecated_ingests" => :none,
    "view_draft_ingests" => :none,
    "view_published_ingests" => :none,
    "view_rejected_ingests" => :none,
    "view_versioned_ingests" => :none
  }

  def get_search_permissions(%Claims{role: role}) when role in ["admin", "service"] do
    Map.new(@defaults, fn {p, _} -> {p, :all} end)
  end

  def get_search_permissions(%Claims{jti: jti}) do
    session_permissions = Permissions.get_session_permissions(jti)
    default_permissions = get_default_permissions()

    session_permissions
    |> Map.take(Map.keys(@defaults))
    |> Map.merge(default_permissions, fn
      _, _, :all -> :all
      _, scope, _ -> scope
    end)
  end

  defp get_default_permissions do
    case Permissions.get_default_permissions() do
      {:ok, permissions} -> Enum.reduce(permissions, @defaults, &Map.replace(&2, &1, :all))
      _ -> @defaults
    end
  end

  def authorized?(%Claims{jti: jti}, permission, domain_id) do
    Permissions.has_permission?(jti, permission, "domain", domain_id)
  end

  def authorized?(%Claims{jti: jti}, permission) do
    Permissions.has_permission?(jti, permission)
  end
end
