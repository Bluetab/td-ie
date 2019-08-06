  defmodule TdIe.Repo.Migrations.AddFileRecordsIngestExecution do
  use Ecto.Migration

  def change do
    alter table (:ingest_executions) do
       add(:records, :integer)
    end
  end
end
