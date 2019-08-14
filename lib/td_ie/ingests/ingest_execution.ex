defmodule TdIe.Ingests.IngestExecution do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "ingest_executions" do
    field(:end_timestamp, :naive_datetime)
    field(:start_timestamp, :naive_datetime)
    field(:status, :string)
    field(:file_name, :string)
    field(:file_size, :integer)
    field(:ingest_id, :id)
    field(:description, :string)
    field(:records, :integer)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ingest_execution, attrs) do
    ingest_execution
    |> cast(attrs, [
      :start_timestamp,
      :end_timestamp,
      :status,
      :file_name,
      :file_size,
      :ingest_id,
      :description,
      :records
    ])
    |> validate_required([:start_timestamp, :status])
  end
end
