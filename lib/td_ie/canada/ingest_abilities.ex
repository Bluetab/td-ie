defmodule TdIe.Canada.IngestAbilities do
  @moduledoc false
  alias TdIe.Accounts.User
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestVersion
  alias TdIe.Permissions

  def can?(%User{is_admin: true}, :create_ingest), do: true

  def can?(%User{} = user, :create_ingest) do
    Permissions.has_any_permission_on_resource_type?(
      user,
      [:create_ingest],
      :domain
    )
  end

  def can?(%User{} = user, :create_ingest, %{
        resource_id: domain_id
      }) do
    Permissions.authorized?(user, :create_ingest, domain_id)
  end

  def can?(%User{} = user, :update, %IngestVersion{} = ingest_version) do
    IngestVersion.is_updatable?(ingest_version) &&
      authorized?(
        user,
        :update_ingest,
        ingest_version
      )
  end

  def can?(
        %User{} = user,
        :send_for_approval,
        %IngestVersion{} = ingest_version
      ) do
    IngestVersion.is_updatable?(ingest_version) &&
      authorized?(
        user,
        :update_ingest,
        ingest_version
      )
  end

  def can?(%User{} = user, :reject, %IngestVersion{} = ingest_version) do
    IngestVersion.is_rejectable?(ingest_version) &&
      authorized?(
        user,
        :reject_ingest,
        ingest_version
      )
  end

  def can?(%User{} = user, :undo_rejection, %IngestVersion{} = ingest_version) do
    IngestVersion.is_undo_rejectable?(ingest_version) &&
      authorized?(
        user,
        :update_ingest,
        ingest_version
      )
  end

  def can?(%User{} = user, :publish, %IngestVersion{} = ingest_version) do
    IngestVersion.is_publishable?(ingest_version) &&
      authorized?(
        user,
        :publish_ingest,
        ingest_version
      )
  end

  def can?(%User{} = user, :version, %IngestVersion{} = ingest_version) do
    IngestVersion.is_versionable?(ingest_version) &&
      authorized?(
        user,
        :update_ingest,
        ingest_version
      )
  end

  def can?(%User{} = user, :deprecate, %IngestVersion{} = ingest_version) do
    IngestVersion.is_deprecatable?(ingest_version) &&
      authorized?(
        user,
        :deprecate_ingest,
        ingest_version
      )
  end

  def can?(%User{} = user, :delete, %IngestVersion{} = ingest_version) do
    IngestVersion.is_deletable?(ingest_version) &&
      authorized?(
        user,
        :delete_ingest,
        ingest_version
      )
  end

  # TODO: Check status is versioned??
  def can?(%User{is_admin: true}, :view_versions, %IngestVersion{}), do: true

  def can?(%User{} = user, :view_versions, %IngestVersion{} = ingest_version) do
    valid_statuses = [
      Ingest.status().draft,
      Ingest.status().pending_approval,
      Ingest.status().rejected,
      Ingest.status().published,
      Ingest.status().versioned,
      Ingest.status().deprecated
    ]

    # TODO: Should be only Ingest.status().versioned??
    IngestVersion.has_any_status?(ingest_version, valid_statuses) &&
      authorized?(
        user,
        :view_versioned_ingests,
        ingest_version
      )
  end

  def can?(%User{is_admin: true}, :view_ingest, %IngestVersion{}), do: true

  def can?(
        %User{} = user,
        :view_ingest,
        %IngestVersion{status: status} = ingest_version
      ) do
    permission = Map.get(Ingest.status_to_permissions(), status)
    authorized?(user, permission, ingest_version)
  end

  def can?(%User{}, _action, _ingest_version), do: false

  defp authorized?(%User{is_admin: true}, _permission, _), do: true

  defp authorized?(%User{} = user, permission, %IngestVersion{ingest: ingest}) do
    domain_id = ingest.domain_id
    Permissions.authorized?(user, permission, domain_id)
  end
end
