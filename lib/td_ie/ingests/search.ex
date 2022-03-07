defmodule TdIe.Ingests.Search do
  @moduledoc """
  Helper module to construct ingest search queries.
  """

  alias TdIe.Auth.Claims
  alias TdIe.Ingests.Search.Aggregations
  alias TdIe.Ingests.Search.Query
  alias TdIe.Permissions
  alias TdIe.Search

  def get_filter_values(%Claims{} = claims, params) do
    query = build_query(claims, params)
    search = %{query: query, aggs: Aggregations.aggregations(), size: 0}
    Search.get_filters(search)
  end

  def list_ingest_versions(ingest_id, claims) do
    params = %{"filters" => %{"ingest_id" => ingest_id}}
    search_ingest_versions(params, claims)
  end

  def search_ingest_versions(params, claims, page \\ 0, size \\ 50)

  def search_ingest_versions(params, %Claims{} = claims, page, size) do
    query = build_query(claims, params)
    sort = Map.get(params, "sort", ["_score", "name.raw"])

    %{from: page * size, size: size, query: query, sort: sort}
    |> do_search()
  end

  defp build_query(%Claims{} = claims, params) do
    claims
    |> Permissions.get_search_permissions()
    |> Query.build_filters()
    |> Query.build_query(params)
  end

  defp do_search(search) do
    case Search.search(search) do
      %{results: results, total: total} ->
        %{results: Enum.map(results, &Map.get(&1, "_source", %{})), total: total}
    end
  end
end
