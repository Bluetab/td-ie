defmodule SearchHelpers do
  @moduledoc """
  Helper functions for mocking search responses.
  """

  import Mox

  @aggs %{
    "foo" => %{
      "buckets" => [%{"key" => "bar"}, %{"key" => "baz"}]
    }
  }

  def aggs_response(aggs \\ @aggs, total \\ 100) do
    {:ok,
     %{
       "aggregations" => aggs,
       "hits" => %{"hits" => [], "total" => %{"relation" => "eq", "value" => total}}
     }}
  end

  def hits_response(hits, total \\ 100) do
    hits = Enum.map(hits, &encode/1)
    {:ok, %{"hits" => %{"hits" => hits, "total" => %{"relation" => "eq", "value" => total}}}}
  end

  defp encode(%TdIe.Ingests.IngestVersion{id: id} = ingest_version) do
    source =
      ingest_version
      |> TdIe.Repo.preload(ingest: :executions)
      |> Elasticsearch.Document.encode()
      |> Jason.encode!()
      |> Jason.decode!()

    %{"_id" => id, "_source" => source}
  end

  def bulk_index_response(items \\ [], took \\ 10) do
    {:ok, %{"errors" => false, "items" => items, "took" => took}}
  end

  def expect_bulk_index(n \\ 1) do
    ElasticsearchMock
    |> expect(:request, n, fn _, :post, "/ingests/_doc/_bulk", _body, [] ->
      bulk_index_response()
    end)
  end
end
