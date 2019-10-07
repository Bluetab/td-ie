defmodule TdIe.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Ingests engine
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdIe.Ingests.IngestVersion
  alias TdIe.Repo

  @impl true
  def stream(IngestVersion) do
    query()
    |> Repo.stream()
    |> Stream.map(&preload/1)
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end

  def list(ids) do
    ids
    |> query()
    |> Repo.all()
    |> Enum.map(&preload/1)
  end

  defp query do
    IngestVersion
    |> join(:inner, [iv], i in assoc(iv, :ingest))
    |> select([iv, i], {iv, i})
  end

  defp query(ids) do
    IngestVersion
    |> where([iv], iv.id in ^ids)
    |> join(:inner, [iv], i in assoc(iv, :ingest))
    |> select([iv, i], {iv, i})
  end

  defp preload({ingest_version, ingest}) do
    Map.put(ingest_version, :ingest, ingest)
  end
end
