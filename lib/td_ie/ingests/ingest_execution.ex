defmodule TdIe.Ingests.IngestExecution do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "ingest_executions" do
    field :end_timestamp, :naive_datetime
    field :start_timestamp, :naive_datetime
    field :status, :string
    field :ingest_id, :id

    timestamps()
  end

  @doc false
  def changeset(ingest_execution, attrs) do
    ingest_execution
    |> cast(attrs, [:start_timestamp, :end_timestamp, :status, :ingest_id])
    |> validate_required([:start_timestamp, :end_timestamp, :status])
  end
end
