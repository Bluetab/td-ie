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
    |> Repo.stream_preload(1000, :ingest)
  end

  def stream(schema, ids) do
    schema
    |> where([i], i.id in ^ids)
    |> select([i], i)
    |> Repo.stream()
    |> Repo.stream_preload(1000, :ingest)
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end
end
