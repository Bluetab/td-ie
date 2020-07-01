defmodule TdIe.Ingests.Ingest do
  @moduledoc """
  Ecto Schema module for Ingests.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestExecution
  alias TdIe.Ingests.IngestVersion

  schema "ingests" do
    field(:domain_id, :integer)
    field(:type, :string)
    field(:last_change_by, :integer)
    field(:last_change_at, :utc_datetime_usec)

    has_many(:versions, IngestVersion)
    has_many(:executions, IngestExecution)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%Ingest{} = ingest, attrs) do
    ingest
    |> cast(attrs, [:domain_id, :type, :last_change_by, :last_change_at])
    |> validate_required([:domain_id, :type, :last_change_by, :last_change_at])
  end
end
