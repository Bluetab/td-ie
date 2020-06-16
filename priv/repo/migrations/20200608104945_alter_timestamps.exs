defmodule TdIe.Repo.Migrations.AlterTimestamps do
  use Ecto.Migration

  def change do
    alter table(:comments) do
      remove(:created_at, :utc_datetime)
      remove(:updated_at, :utc_datetime)
      modify(:inserted_at, :utc_datetime_usec, from: :utc_datetime)
    end

    alter table(:ingests) do
      modify(:last_change_at, :utc_datetime_usec, from: :utc_datetime)
      modify(:inserted_at, :utc_datetime_usec, from: :utc_datetime)
      modify(:updated_at, :utc_datetime_usec, from: :utc_datetime)
    end

    alter table(:ingest_versions) do
      modify(:last_change_at, :utc_datetime_usec, from: :utc_datetime)
      modify(:inserted_at, :utc_datetime_usec, from: :utc_datetime)
      modify(:updated_at, :utc_datetime_usec, from: :utc_datetime)
    end

    alter table(:ingest_executions) do
      modify(:inserted_at, :utc_datetime_usec, from: :utc_datetime)
      modify(:updated_at, :utc_datetime_usec, from: :utc_datetime)
    end
  end
end
