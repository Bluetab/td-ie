defmodule TdIe.Permissions.MockPermissionResolver do
  @moduledoc """
  A mock permissions resolver defining the default permissions for the admin, watch, create and publish
  roles
  """
  use Agent

  alias Poision
  alias TdCache.TaxonomyCache

  @role_permissions %{
    "admin" => [
      :create_ingest,
      :update_ingest,
      :send_ingest_for_approval,
      :delete_ingest,
      :publish_ingest,
      :reject_ingest,
      :deprecate_ingest,
      :view_draft_ingests,
      :view_approval_pending_ingests,
      :view_published_ingests,
      :view_versioned_ingests,
      :view_rejected_ingests,
      :view_deprecated_ingests
    ],
    "publish" => [
      :create_ingest,
      :update_ingest,
      :send_ingest_for_approval,
      :delete_ingest,
      :publish_ingest,
      :reject_ingest,
      :deprecate_ingest,
      :view_draft_ingests,
      :view_approval_pending_ingests,
      :view_published_ingests,
      :view_versioned_ingests,
      :view_rejected_ingests,
      :view_deprecated_ingests
    ],
    "watch" => [
      :view_published_ingests,
      :view_versioned_ingests,
      :view_deprecated_ingests,
      :view_draft_ingests,
      :view_rejected_ingests
    ],
    "create" => [
      :create_ingest,
      :update_ingest,
      :send_ingest_for_approval,
      :delete_ingest,
      :view_draft_ingests,
      :view_published_ingests,
      :view_versioned_ingests,
      :view_approval_pending_ingests,
      :view_deprecated_ingests
    ]
  }

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: :MockPermissions)
    Agent.start_link(fn -> Map.new() end, name: :MockSessions)
  end

  def has_permission?(session_id, permission, "domain", domain_id) do
    domain_id
    |> TaxonomyCache.get_parent_ids()
    |> Enum.any?(&has_resource_permission?(session_id, permission, "domain", &1))
  end

  def has_resource_permission?(session_id, permission, resource_type, resource_id) do
    user_id = Agent.get(:MockSessions, &Map.get(&1, session_id))

    Agent.get(:MockPermissions, & &1)
    |> Enum.filter(
      &(&1.principal_id == user_id && &1.resource_type == resource_type &&
          &1.resource_id == resource_id)
    )
    |> Enum.any?(&can?(&1.role_name, permission))
  end

  defp can?("admin", _permission), do: true

  defp can?(role, permission) do
    case Map.get(@role_permissions, role) do
      nil -> false
      permissions -> Enum.member?(permissions, permission)
    end
  end

  def create_acl_entry(item) do
    Agent.update(:MockPermissions, &[item | &1])
  end

  def get_acl_entries do
    Agent.get(:MockPermissions, & &1)
  end

  def register_token(resource) do
    %{"sub" => sub, "jti" => jti} = resource |> Map.take(["sub", "jti"])
    %{"id" => user_id} = sub |> Poison.decode!()
    Agent.update(:MockSessions, &Map.put(&1, jti, user_id))
  end

  def get_acls_by_resource_type(session_id, resource_type) do
    user_id = Agent.get(:MockSessions, &Map.get(&1, session_id))

    Agent.get(:MockPermissions, & &1)
    |> Enum.filter(&(&1.principal_id == user_id && &1.resource_type == resource_type))
    |> Enum.map(fn %{role_name: role_name} = map ->
      Map.put(map, :permissions, Map.get(@role_permissions, role_name))
    end)
    |> Enum.map(&Map.take(&1, [:resource_type, :resource_id, :permissions, :role_name]))
  end
end
