defmodule TdIe.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: TdIe.Repo
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestExecution
  alias TdIe.Ingests.IngestVersion

  def user_factory do
    %TdIe.Accounts.User{
      id: 0,
      user_name: "bufoncillo",
      is_admin: false,
      jti: 0
    }
  end

  def ingest_factory do
    %Ingest{
      domain_id: 1,
      type: "some_type",
      last_change_by: 1,
      last_change_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  def ingest_version_factory do
    %IngestVersion{
      ingest: build(:ingest),
      content: %{},
      name: "My ingest",
      description: %{"document" => "My ingest description"},
      last_change_by: 1,
      last_change_at: DateTime.utc_now() |> DateTime.truncate(:second),
      status: Ingest.status().draft,
      version: 1,
      in_progress: false
    }
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
