defmodule TdIe.Ingests.IngestAlias do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestAlias

  schema "ingest_aliases" do
    field :name, :string
    belongs_to :ingest, Ingest

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(%IngestAlias{} = ingest_alias, attrs) do
    ingest_alias
    |> cast(attrs, [:name, :ingest_id])
    |> validate_required([:name, :ingest_id])
    |> validate_length(:name, max: 255)
  end
end
