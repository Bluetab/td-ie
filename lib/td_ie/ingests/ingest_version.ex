defmodule TdIe.Ingests.IngestVersion do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias TdIe.Ingests
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestVersion

  schema "ingest_versions" do
    field(:content, :map)
    field(:description, :map)
    field(:last_change_at, :utc_datetime)
    field(:mod_comments, :string)
    field(:last_change_by, :integer)
    field(:name, :string)
    field(:reject_reason, :string)
    field(:status, :string)
    field(:current, :boolean, default: true)
    field(:version, :integer)
    field(:in_progress, :boolean, default: false)
    belongs_to(:ingest, Ingest, on_replace: :update)

    timestamps(type: :utc_datetime)
  end

  @doc false
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
    |> put_change(:status, Ingest.status().draft)
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
    |> put_change(:status, Ingest.status().draft)
    |> validate_required([
      :content,
      :name,
      :last_change_by,
      :last_change_at,
      :in_progress
    ])
    |> validate_length(:name, max: 255)
    |> validate_length(:mod_comments, max: 500)
  end

  @doc false
  def update_status_changeset(%IngestVersion{} = ingest_version, attrs) do
    ingest_version
    |> cast(attrs, [:status])
    |> validate_required([:status])
    |> validate_inclusion(:status, Map.values(Ingest.status()))
  end

  @doc false
  def not_anymore_current_changeset(%IngestVersion{} = ingest_version) do
    ingest_version
    |> cast(%{}, [])
    |> put_change(:current, false)
  end

  @doc false
  def current_changeset(%IngestVersion{} = ingest_version) do
    ingest_version
    |> Map.get(:ingest_id)
    |> Ingests.get_current_version_by_ingest_id!(%{current: false})
    |> cast(%{}, [])
    |> put_change(:current, true)
  end

  @doc false
  def reject_changeset(%IngestVersion{} = ingest_version, attrs) do
    ingest_version
    |> cast(attrs, [:reject_reason])
    |> validate_length(:reject_reason, max: 500)
    |> put_change(:status, Ingest.status().rejected)
  end

  @doc false
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
  end

  def has_any_status?(%IngestVersion{status: status}, statuses),
    do: has_any_status?(status, statuses)

  def has_any_status?(_status, []), do: false

  def has_any_status?(status, [h | t]) do
    status == h || has_any_status?(status, t)
  end

  def is_updatable?(%IngestVersion{current: current, status: status}) do
    current && status == Ingest.status().draft
  end

  def is_publishable?(%IngestVersion{current: current, status: status}) do
    current && status == Ingest.status().pending_approval
  end

  def is_rejectable?(%IngestVersion{} = ingest_version),
    do: is_publishable?(ingest_version)

  def is_versionable?(%IngestVersion{current: current, status: status}) do
    current && status == Ingest.status().published
  end

  def is_deprecatable?(%IngestVersion{} = ingest_version),
    do: is_versionable?(ingest_version)

  def is_undo_rejectable?(%IngestVersion{current: current, status: status}) do
    current && status == Ingest.status().rejected
  end

  def is_deletable?(%IngestVersion{current: current, status: status}) do
    valid_statuses = [Ingest.status().draft, Ingest.status().rejected]
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
      %{type: type, domain_id: domain_id} = ingest
      template = TemplateCache.get_by_name!(type) || %{content: []}
      domain = Ingests.get_domain(domain_id)
      domain_ids = fetch_parent_ids(domain_id)
      domain_parents = Enum.map(domain_ids, &TaxonomyCache.get_domain/1)

      content =
        iv
        |> Map.get(:content)
        |> Format.search_values(template)

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
    end

    defp fetch_parent_ids(nil), do: []

    defp fetch_parent_ids(domain_id), do: TaxonomyCache.get_parent_ids(domain_id)

    defp get_last_change_by(%IngestVersion{last_change_by: last_change_by}) do
      get_user(last_change_by)
    end

    defp get_user(user_id) do
      case UserCache.get(user_id) do
        {:ok, nil} -> %{}
        {:ok, user} -> user
      end
    end
  end
end
