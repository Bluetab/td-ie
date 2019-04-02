defmodule TdIe.Repo.Migrations.AddFileNameAndFileSize do
  use Ecto.Migration

  def change do
    alter table(:ingest_executions) do
      add(:file_name, :string)
      add(:file_size, :integer)
    end
  end
end
