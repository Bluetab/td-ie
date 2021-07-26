defmodule TdIe.Repo.Migrations.ChangeFileSizeIngestExecutions do
  use Ecto.Migration

  def change do
    alter table(:ingest_executions) do
      modify(:file_size, :bigint)
    end
  end
end
