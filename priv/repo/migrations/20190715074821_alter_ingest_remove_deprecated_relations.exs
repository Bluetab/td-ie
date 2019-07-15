defmodule TdIe.Repo.Migrations.AlterIngestRemoveDeprecatedRelations do
  use Ecto.Migration

  def change do
    alter(table(:ingest_versions), do: remove(:related_to))
    alter(table(:ingests), do: remove(:parent_id))
  end
end
