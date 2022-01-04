defmodule TdIe.Ingests.IngestVersion do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

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

  def create_changeset(%IngestVersion{} = ingest_version, attrs) do
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
    |> maybe_put_identifier(attrs)
    |> put_change(:status, "draft")
    |> validate_length(:name, max: 255)
    |> validate_length(:mod_comments, max: 500)
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
  end

  def status_changeset(%IngestVersion{} = ingest_version, status, user_id) do
    ingest_version
    |> cast(%{status: status}, [:status])
    |> validate_required([:status])
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
  end

  defp maybe_put_identifier(changeset, %IngestVersion{
    content: current_content,
    ingest: %{type: template_name}
  }) do
    maybe_put_identifier_aux(changeset, current_content, template_name)
  end

  defp maybe_put_identifier(changeset, %{ingest: %{type: template_name}} = _attrs) do
    maybe_put_identifier_aux(changeset, %{}, template_name)
  end

  defp maybe_put_identifier(changeset, _) do
    changeset
  end

  defp maybe_put_identifier_aux(
         %{valid?: true, changes: %{content: content}} = changeset,
         current_content,
         template_name
       ) do
    TdDfLib.Format.maybe_put_identifier(current_content, content, template_name)
    |> (fn content ->
          put_change(changeset, :content, content)
        end).()
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

  defimpl Elasticsearch.Document do
    alias TdCache.TaxonomyCache
    alias TdCache.TemplateCache
    alias TdCache.UserCache
    alias TdDfLib.Format
    alias TdDfLib.RichText

    @impl Elasticsearch.Document
    def id(%IngestVersion{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(%IngestVersion{ingest: ingest} = iv) do
      %{type: type, domain_id: domain_id, executions: executions} = ingest

      template = TemplateCache.get_by_name!(type) || %{content: []}
      domain = Ingests.get_domain(domain_id) || %{}
      domain_ids = fetch_parent_ids(domain_id)
      domain_parents = Enum.map(domain_ids, &get_domain/1)
      last_execution = Ingests.get_last_execution(executions)

      content =
        iv
        |> Map.get(:content)
        |> Format.search_values(template, domain_id: domain_id)

      iv
      |> Map.take([
        :id,
        :ingest_id,
        :name,
        :status,
        :version,
        :last_change_at,
        :current,
        :in_progress,
        :inserted_at
      ])
      |> Map.put(:content, content)
      |> Map.put(:description, RichText.to_plain_text(iv.description))
      |> Map.put(:domain, Map.take(domain, [:id, :name, :external_id]))
      |> Map.put(:domain_ids, domain_ids)
      |> Map.put(:domain_parents, domain_parents)
      |> Map.put(:last_change_by, get_last_change_by(iv))
      |> Map.put(:template, Map.take(template, [:name, :label]))
      |> Map.put(:execution_status, Map.get(last_execution, :status))
      |> Map.put(:last_execution, Map.get(last_execution, :execution))
    end

    defp fetch_parent_ids(nil), do: []

    defp fetch_parent_ids(domain_id), do: TaxonomyCache.get_parent_ids(domain_id)

    defp get_domain(id) do
      case TaxonomyCache.get_domain(id) do
        %{} = domain -> Map.take(domain, [:id, :external_id, :name])
        nil -> %{id: id}
      end
    end

    defp get_last_change_by(%IngestVersion{last_change_by: last_change_by}) do
      get_user(last_change_by)
    end

    defp get_user(user_id) do
      case UserCache.get(user_id) do
        {:ok, nil} -> %{}
        {:ok, %{} = user} -> Map.drop(user, [:email, :is_admin])
      end
    end
  end
end
