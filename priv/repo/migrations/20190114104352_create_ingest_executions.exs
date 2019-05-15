defmodule TdIe.Repo.Migrations.CreateIngestExecutions do
  use Ecto.Migration

  def change do
    create table(:ingest_executions) do
      add(:start_timestamp, :naive_datetime_usec)
      add(:end_timestamp, :naive_datetime_usec)
      add(:status, :string)
      add(:ingest_id, references(:ingests, on_delete: :nothing))

      timestamps(type: :utc_datetime)
    end

    create(index(:ingest_executions, [:ingest_id]))
  end
end
