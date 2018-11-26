defmodule TdIe.Repo.Migrations.CreateIngests do
  @moduledoc """
  Migration to create ingests tables
  """
  use Ecto.Migration

  def change do
    create table(:ingests) do
      add :type, :string, null: false
      add :last_change_by, :bigint, null: false
      add :last_change_at, :utc_datetime, null: false
      add :parent_id, references(:ingests), null: true
      add :domain_id, :bigint, null: true

      timestamps(type: :utc_datetime)
    end
  end
end
