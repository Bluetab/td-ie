defmodule TdIe.Canada.IngestAbilities do
  @moduledoc false
  alias TdIe.Auth.Claims
  alias TdIe.Ingests.IngestVersion
  alias TdIe.Permissions

  @status_to_permissions %{
    "pending_approval" => :view_approval_pending_ingests,
    "deprecated" => :view_deprecated_ingests,
    "draft" => :view_draft_ingests,
    "published" => :view_published_ingests,
    "rejected" => :view_rejected_ingests,
    "versioned" => :view_versioned_ingests
  }

  def can?(%Claims{role: "admin"}, :create_ingest), do: true

  def can?(%Claims{} = claims, :create_ingest) do
    Permissions.authorized?(claims, :create_ingest)
  end

  def can?(%Claims{} = claims, :create_ingest, %{resource_id: domain_id}) do
    Permissions.authorized?(claims, :create_ingest, domain_id)
  end

  def can?(%Claims{} = claims, :update, %IngestVersion{} = ingest_version) do
    IngestVersion.updatable?(ingest_version) &&
      authorized?(claims, :update_ingest, ingest_version)
  end

  def can?(%Claims{} = claims, :send_for_approval, %IngestVersion{} = ingest_version) do
    IngestVersion.updatable?(ingest_version) &&
      authorized?(claims, :update_ingest, ingest_version)
  end

  def can?(%Claims{} = claims, :reject, %IngestVersion{} = ingest_version) do
    IngestVersion.rejectable?(ingest_version) &&
      authorized?(claims, :reject_ingest, ingest_version)
  end

  def can?(%Claims{} = claims, :undo_rejection, %IngestVersion{} = ingest_version) do
    IngestVersion.undo_rejectable?(ingest_version) &&
      authorized?(claims, :update_ingest, ingest_version)
  end

  def can?(%Claims{} = claims, :publish, %IngestVersion{} = ingest_version) do
    IngestVersion.publishable?(ingest_version) &&
      authorized?(claims, :publish_ingest, ingest_version)
  end

  def can?(%Claims{} = claims, :version, %IngestVersion{} = ingest_version) do
    IngestVersion.versionable?(ingest_version) &&
      authorized?(claims, :update_ingest, ingest_version)
  end

  def can?(%Claims{} = claims, :deprecate, %IngestVersion{} = ingest_version) do
    IngestVersion.deprecatable?(ingest_version) &&
      authorized?(claims, :deprecate_ingest, ingest_version)
  end

  def can?(%Claims{} = claims, :delete, %IngestVersion{} = ingest_version) do
    IngestVersion.deletable?(ingest_version) &&
      authorized?(claims, :delete_ingest, ingest_version)
  end

  def can?(%Claims{role: "admin"}, :view_ingest, %IngestVersion{}), do: true

  def can?(%Claims{} = claims, :view_ingest, %IngestVersion{status: status} = ingest_version) do
    permission = Map.get(@status_to_permissions, status)
    authorized?(claims, permission, ingest_version)
  end

  def can?(%Claims{}, _action, _ingest_version), do: false

  defp authorized?(%Claims{role: "admin"}, _permission, _), do: true

  defp authorized?(%Claims{} = claims, permission, %IngestVersion{ingest: ingest}) do
    authorized?(claims, permission, ingest)
  end

  defp authorized?(%Claims{} = claims, permission, %{domain_id: domain_id}) do
    Permissions.authorized?(claims, permission, domain_id)
  end
end
