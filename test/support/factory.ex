defmodule TdIe.Factory do
  @moduledoc """
  ExMachina factory for Ingest tests
  """

  use ExMachina.Ecto, repo: TdIe.Repo
  use TdDfLib.TemplateFactory

  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestExecution
  alias TdIe.Ingests.IngestVersion

  def domain_factory do
    %{
      id: sequence(:domain_id, &(&1 + 1_000_000)),
      name: "domain name",
      parent_ids: [],
      updated_at: DateTime.utc_now()
    }
  end

  def claims_factory(attrs) do
    %TdIe.Auth.Claims{
      user_id: sequence(:user_id, & &1),
      user_name: sequence("user_name"),
      role: "user",
      jti: sequence("jti"),
      is_admin: Map.get(attrs, :role) == "admin"
    }
    |> merge_attributes(attrs)
  end

  def ingest_factory(attrs) do
    %Ingest{
      domain_id: 1,
      type: "some_type",
      last_change_by: 1,
      last_change_at: DateTime.utc_now()
    }
    |> merge_attributes(attrs)
  end

  def ingest_version_factory(attrs) do
    {ingest_attrs, attrs} = Map.split(attrs, [:domain_id])

    %IngestVersion{
      ingest: build(:ingest, ingest_attrs),
      content: %{},
      name: "My ingest",
      description: %{"document" => "My ingest description"},
      last_change_by: 1,
      last_change_at: DateTime.utc_now(),
      status: "draft",
      version: 1,
      in_progress: false
    }
    |> merge_attributes(attrs)
  end

  def ingest_execution_factory do
    %IngestExecution{
      ingest_id: insert(:ingest).id,
      start_timestamp: ~N[2010-04-17 14:00:00.000000],
      end_timestamp: ~N[2010-04-17 14:00:00.000000],
      status: "status"
    }
  end
end
