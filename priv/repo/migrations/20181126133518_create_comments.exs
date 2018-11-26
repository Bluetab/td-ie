defmodule TdIe.Repo.Migrations.CreateComments do
  @moduledoc """
  Migration to create table comments
  """
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :content, :text
      add :resource_id, :integer
      add :resource_type, :string
      add :user, :map
      add :created_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
