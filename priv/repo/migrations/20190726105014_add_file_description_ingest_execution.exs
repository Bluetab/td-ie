defmodule TdIe.Repo.Migrations.AddFileDescriptionIngestExecution do
  use Ecto.Migration

  def change do
    alter table(:ingest_executions) do
      add(:description, :text)
    end
  end
end
