defmodule TdIe.Repo.Migrations.CreateIngestVersions do
  @moduledoc """
  Create table ingest_versions
  """
  use Ecto.Migration

  def change do
    create table(:ingest_versions) do
      add :ingest_id, references(:ingests), null: false
      add :name, :string, null: false, size: 255
      add :content, :map
      add :current, :boolean, default: true, null: false
      add :description, :map
      add :in_progress, :boolean, default: false, null: false
      add :last_change_by, :bigint, null: false
      add :last_change_at, :utc_datetime, null: false
      add :status, :string, null: false
      add :version, :integer, null: false
      add :reject_reason, :string, size: 500, null: true
      add :related_to, {:array, :integer}, null: false
      add :mod_comments, :string, size: 500, null: true

      timestamps(type: :utc_datetime)
    end
  end
end
