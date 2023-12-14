defmodule TdIe.Ingests.IngestVersion do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDfLib.Validation
  alias TdIe.Ingests
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestVersion

  @valid_status ["draft", "pending_approval", "rejected", "published", "versioned", "deprecated"]

  schema "ingest_versions" do
    field(:content, :map)
    field(:description, :map)
    field(:last_change_at, :utc_datetime_usec)
    field(:mod_comments, :string)
    field(:last_change_by, :integer)
    field(:name, :string)
    field(:reject_reason, :string)
    field(:status, :string)
    field(:current, :boolean, default: true)
    field(:version, :integer)
    field(:in_progress, :boolean, default: false)
    belongs_to(:ingest, Ingest, on_replace: :update)

    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(
        %IngestVersion{} = ingest_version,
        attrs,
        old_ingest_version \\ %IngestVersion{}
      ) do
    ingest_version
    |> cast(attrs, [
      :content,
      :name,
      :description,
      :last_change_by,
      :last_change_at,
      :version,
      :mod_comments,
      :in_progress
    ])
    |> put_assoc(:ingest, attrs.ingest)
    |> validate_required([
      :content,
      :name,
      :last_change_by,
      :last_change_at,
      :version,
      :ingest,
      :in_progress
    ])
    |> maybe_put_identifier(attrs, old_ingest_version)
    |> put_change(:status, "draft")
    |> validate_length(:name, max: 255)
    |> validate_length(:mod_comments, max: 500)
    |> validate_change(:description, &Validation.validate_safe/2)
    |> validate_change(:content, &Validation.validate_safe/2)
  end

  def update_changeset(%IngestVersion{} = ingest_version, attrs) do
    ingest_version
    |> cast(attrs, [
      :content,
      :name,
      :description,
      :last_change_by,
      :last_change_at,
      :mod_comments,
      :in_progress
    ])
    |> cast_assoc(:ingest)
    |> put_change(:status, "draft")
    |> validate_required([
      :content,
      :name,
      :last_change_by,
      :last_change_at,
      :in_progress
    ])
    |> maybe_put_identifier(ingest_version)
    |> validate_length(:name, max: 255)
    |> validate_length(:mod_comments, max: 500)
    |> validate_change(:description, &Validation.validate_safe/2)
    |> validate_change(:content, &Validation.validate_safe/2)
  end

  def status_changeset(%IngestVersion{} = ingest_version, status, user_id) do
    ingest_version
    |> cast(%{status: status}, [:status])
    |> validate_required(:status)
    |> validate_inclusion(:status, @valid_status)
    |> put_audit(user_id)
  end

  def current_changeset(%IngestVersion{} = ingest_version) do
    ingest_version
    |> Map.get(:ingest_id)
    |> Ingests.get_current_version_by_ingest_id!(%{current: false})
    |> cast(%{}, [])
    |> put_change(:current, true)
  end

  def reject_changeset(%IngestVersion{} = ingest_version, %{} = params, user_id) do
    ingest_version
    |> cast(params, [:reject_reason])
    |> validate_length(:reject_reason, max: 500)
    |> put_change(:status, "rejected")
    |> put_audit(user_id)
  end

  def changeset(%IngestVersion{} = ingest_version, attrs) do
    ingest_version
    |> cast(attrs, [
      :name,
      :description,
      :content,
      :last_change_by,
      :last_change_at,
      :status,
      :version,
      :reject_reason,
      :mod_comments,
      :in_progress
    ])
    |> validate_required([
      :name,
      :description,
      :content,
      :last_change_by,
      :last_change_at,
      :status,
      :version,
      :reject_reason,
      :mod_comments,
      :in_progress
    ])
    |> maybe_put_identifier(ingest_version)
    |> validate_change(:description, &Validation.validate_safe/2)
    |> validate_change(:content, &Validation.validate_safe/2)
  end

  defp maybe_put_identifier(
         changeset,
         _attrs,
         %IngestVersion{content: _old_content, ingest: %{type: _template_name}} = ingest_version
       ) do
    maybe_put_identifier(changeset, ingest_version)
  end

  defp maybe_put_identifier(
         changeset,
         %{ingest: %{type: _template_name}} = attrs,
         _ingest_version
       ) do
    maybe_put_identifier(changeset, attrs)
  end

  defp maybe_put_identifier(
         changeset,
         _attrs,
         _ingest_version
       ) do
    changeset
  end

  defp maybe_put_identifier(changeset, %IngestVersion{
         content: old_content,
         ingest: %{type: template_name}
       }) do
    maybe_put_identifier_aux(changeset, old_content, template_name)
  end

  defp maybe_put_identifier(changeset, %{ingest: %{type: template_name}} = _attrs) do
    maybe_put_identifier_aux(changeset, %{}, template_name)
  end

  defp maybe_put_identifier(changeset, _old_ingest_version_or_attrs) do
    changeset
  end

  defp maybe_put_identifier_aux(
         %{valid?: true, changes: %{content: changeset_content}} = changeset,
         old_content,
         template_name
       ) do
    new_content =
      TdDfLib.Format.maybe_put_identifier(changeset_content, old_content, template_name)

    put_change(changeset, :content, new_content)
  end

  defp maybe_put_identifier_aux(changeset, _, _) do
    changeset
  end

  defp put_audit(%{changes: changes} = changeset, _user_id) when changes == %{}, do: changeset

  defp put_audit(%{} = changeset, user_id) do
    changeset
    |> put_change(:last_change_by, user_id)
    |> put_change(:last_change_at, DateTime.utc_now())
  end

  def has_any_status?(%IngestVersion{status: status}, statuses),
    do: has_any_status?(status, statuses)

  def has_any_status?(_status, []), do: false

  def has_any_status?(status, [h | t]) do
    status == h || has_any_status?(status, t)
  end

  def is_updatable?(%IngestVersion{current: current, status: status}) do
    current && status == "draft"
  end

  def is_publishable?(%IngestVersion{current: current, status: status}) do
    current && status == "pending_approval"
  end

  def is_rejectable?(%IngestVersion{} = ingest_version),
    do: is_publishable?(ingest_version)

  def is_versionable?(%IngestVersion{current: current, status: status}) do
    current && status == "published"
  end

  def is_deprecatable?(%IngestVersion{} = ingest_version),
    do: is_versionable?(ingest_version)

  def is_undo_rejectable?(%IngestVersion{current: current, status: status}) do
    current && status == "rejected"
  end

  def is_deletable?(%IngestVersion{current: current, status: status}) do
    valid_statuses = ["draft", "rejected"]
    current && Enum.member?(valid_statuses, status)
  end
end
