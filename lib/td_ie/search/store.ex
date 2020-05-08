defmodule TdIe.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Ingests engine
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdIe.Repo

  @impl true
  def stream(schema) do
    schema
    |> select([i], i)
    |> Repo.stream()
    |> Repo.stream_preload(1000, [ingest: :executions])
  end

  def stream(schema, ids) do
    schema
    |> where([i], i.ingest_id in ^ids)
    |> select([i], i)
    |> Repo.stream()
    |> Repo.stream_preload(1000, [ingest: :executions])
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end
end
