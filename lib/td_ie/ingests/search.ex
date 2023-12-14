defmodule TdIe.Ingests.Search do
  @moduledoc """
  Helper module to construct ingest search queries.
  """

  alias TdCore.Search
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdCore.Search.Permissions
  alias TdIe.Auth.Claims
  alias TdIe.Ingests.IngestVersion
  alias TdIe.Ingests.Search.Query
  alias TdIe.Permissions, as: TdIePermissions

  @index :ingests

  def get_filter_values(%Claims{} = claims, params) do
    query = build_query(claims, params)
    aggs = ElasticDocumentProtocol.aggregations(%IngestVersion{})
    search = %{query: query, aggs: aggs, size: 0}
    {:ok, response} = Search.get_filters(search, @index)
    response
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
    permissions = TdIePermissions.get_default_permissions()

    permissions
    |> Permissions.get_search_permissions(claims)
    |> Query.build_filters()
    |> Query.build_query(params)
  end

  defp do_search(search) do
    case Search.search(search, @index) do
      {:ok, %{results: results, total: total}} ->
        %{results: Enum.map(results, &Map.get(&1, "_source", %{})), total: total}
    end
  end
end
