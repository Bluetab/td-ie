defmodule TdIe.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Ingests engine
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdIe.Repo

  alias TdCluster.Cluster.TdDd.Tasks
  alias TdIe.Ingests.IngestVersion

  @impl true
  def stream(IngestVersion = schema) do
    count = Repo.aggregate(IngestVersion, :count, :id)
    Tasks.log_start_stream(count)

    result =
      schema
      |> select([i], i)
      |> Repo.stream()
      |> Repo.stream_preload(1000, ingest: :executions)

    Tasks.log_progress(count)

    result
  end

  def stream(IngestVersion = schema, ids) do
    count = Repo.aggregate(IngestVersion, :count, :id)
    Tasks.log_start_stream(count)

    schema
    |> where([i], i.ingest_id in ^ids)
    |> select([i], i)
    |> Repo.stream()
    |> Repo.stream_preload(1000, ingest: :executions)
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end
end
