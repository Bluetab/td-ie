defmodule TdIe.Ingests.Ingest do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestVersion

  @status %{
    draft: "draft",
    pending_approval: "pending_approval",
    rejected: "rejected",
    published: "published",
    versioned: "versioned",
    deprecated: "deprecated"
  }

  schema "ingests" do
    belongs_to(:parent, Ingest)
    has_many(:children, Ingest, foreign_key: :parent_id)
    field(:domain_id, :integer)
    field(:type, :string)
    field(:last_change_by, :integer)
    field(:last_change_at, :utc_datetime)

    has_many(:versions, IngestVersion)

    timestamps(type: :utc_datetime)
  end

  def status do
    @status
  end

  def status_values do
    @status |> Map.values()
  end

  def permissions_to_status do
    status = Ingest.status()

    %{
      view_approval_pending_ingests: status.pending_approval,
      view_deprecated_ingests: status.deprecated,
      view_draft_ingests: status.draft,
      view_published_ingests: status.published,
      view_rejected_ingests: status.rejected,
      view_versioned_ingests: status.versioned
    }
  end

  def status_to_permissions do
    Enum.reduce(Ingest.permissions_to_status(), %{}, fn {k, v}, acc -> Map.put(acc, v, k) end)
  end

  @doc false
  def changeset(%Ingest{} = ingest, attrs) do
    ingest
    |> cast(attrs, [:domain_id, :type, :last_change_by, :last_change_at, :parent_id])
    |> validate_required([:domain_id, :type, :last_change_by, :last_change_at])
  end
end
