defmodule TdIe.Repo.Migrations.IngestAliases do
  @moduledoc """
  Migration to create table ingest_aliases
  """
  use Ecto.Migration

  def change do
    create table(:ingest_aliases) do
      add :name, :string
      add :ingest_id, references(:ingests, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:ingest_aliases, [:ingest_id])
  end
end
