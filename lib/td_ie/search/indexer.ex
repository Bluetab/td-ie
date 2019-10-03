defmodule TdIe.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """

  alias Elasticsearch.Index
  alias Elasticsearch.Index.Bulk
  alias Jason, as: JSON
  alias TdIe.Ingests.IngestVersion
  alias TdIe.Search.Mappings
  alias TdIe.Search.Store

  @index "ingests"
  @index_config Application.get_env(:td_ie, TdIe.Search.Cluster, :indexes)

  require Logger

  def reindex(:ingest) do
    template =
      Mappings.get_mappings()
      |> Map.put(:index_patterns, "#{@index}-*")
      |> JSON.encode!()

    {:ok, _} = Elasticsearch.put(Cluster, "/_template/#{@index}", template)

    Index.hot_swap(Cluster, @index)
  end

  def reindex(ids, :ingest) do
    %{bulk_page_size: bulk_page_size} =
      @index_config
      |> Keyword.get(:indexes)
      |> Map.get(:ingests)

    ids
    |> Stream.chunk_every(bulk_page_size)
    |> Stream.map(&Store.list(&1))
    |> Stream.map(fn chunk ->
      time(bulk_page_size, fn ->
        bulk =
          chunk
          |> Enum.map(&Bulk.encode!(Cluster, &1, @index, "index"))
          |> Enum.join("")

        Elasticsearch.post(Cluster, "/#{@index}/_doc/_bulk", bulk)
      end)
    end)
    |> Stream.run()
  end

  def delete(ids, :ingest) when is_list(ids) do
    Enum.each(ids, &delete/1)
  end

  defp delete(id) do
    Elasticsearch.delete_document(Cluster, %IngestVersion{id: id}, @index)
  end

  defp time(bulk_page_size, fun) do
    {millis, res} = Timer.time(fun)

    case millis do
      0 ->
        Logger.info("Indexing rate :infinity items/s")

      millis ->
        rate = div(1_000 * bulk_page_size, millis)
        Logger.info("Indexing rate #{rate} items/s")
    end

    res
  end
end
