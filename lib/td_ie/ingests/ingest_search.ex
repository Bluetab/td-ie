defmodule TdIe.Ingest.Search do
  @moduledoc """
  Helper module to construct ingest search queries.
  """

  alias TdIe.Auth.Claims
  alias TdIe.Ingest.Query
  alias TdIe.Permissions
  alias TdIe.Search
  alias TdIe.Search.Aggregations

  @permissions_to_status %{
    view_approval_pending_ingests: "pending_approval",
    view_deprecated_ingests: "deprecated",
    view_draft_ingests: "draft",
    view_published_ingests: "published",
    view_rejected_ingests: "rejected",
    view_versioned_ingests: "versioned"
  }

  def get_filter_values(%Claims{is_admin: true}, params) do
    filter_clause = create_filters(params)
    query = create_query(%{}, filter_clause)
    search = %{query: query, aggs: Aggregations.aggregation_terms()}
    Search.get_filters(search)
  end

  def get_filter_values(%Claims{} = claims, params) do
    permissions = Permissions.get_domain_permissions(claims)
    get_filter_values(permissions, params)
  end

  def get_filter_values([], _), do: %{}

  def get_filter_values(permissions, params) do
    filter_clause = create_filters(params)
    filter = create_filter_clause(permissions, filter_clause)
    query = create_query(%{}, filter)
    search = %{query: query, aggs: Aggregations.aggregation_terms()}
    Search.get_filters(search)
  end

  def search_ingest_versions(params, claims, page \\ 0, size \\ 50)

  # Admin user search, no filters applied
  def search_ingest_versions(params, %Claims{is_admin: true}, page, size) do
    filter_clause = create_filters(params)

    query =
      case filter_clause do
        [] -> create_query(params)
        _ -> create_query(params, filter_clause)
      end

    sort = Map.get(params, "sort", ["_score", "name.raw"])

    search = %{
      from: page * size,
      size: size,
      query: query,
      aggs: Aggregations.aggregation_terms(),
      sort: sort
    }

    do_search(search)
  end

  # Non-admin user search, filters applied
  def search_ingest_versions(params, %Claims{} = claims, page, size) do
    permissions = Permissions.get_domain_permissions(claims)
    filter_ingest_versions(params, permissions, page, size)
  end

  def list_ingest_versions(ingest_id, %Claims{is_admin: true}) do
    query = %{ingest_id: ingest_id} |> create_query

    %{query: query}
    |> do_search
  end

  def list_ingest_versions(ingest_id, %Claims{} = claims) do
    permissions = Permissions.get_domain_permissions(claims)
    predefined_query = %{ingest_id: ingest_id} |> create_query
    filter = permissions |> create_filter_clause([predefined_query])
    query = create_query(nil, filter)

    %{query: query}
    |> do_search
  end

  def create_filters(%{"filters" => filters}) do
    filters
    |> Map.to_list()
    |> Enum.map(&to_terms_query/1)
  end

  def create_filters(_), do: []

  defp to_terms_query({filter, values}) do
    Aggregations.aggregation_terms()
    |> Map.get(filter)
    |> get_filter(values)
  end

  defp get_filter(%{terms: %{field: field}}, values) do
    %{terms: %{field => values}}
  end

  defp get_filter(%{aggs: %{distinct_search: distinct_search}, nested: %{path: path}}, values) do
    %{nested: %{path: path, query: build_nested_query(distinct_search, values)}}
  end

  defp build_nested_query(%{terms: %{field: field}}, values) do
    %{terms: %{field => values}} |> bool_query()
  end

  defp filter_ingest_versions(_params, [], _page, _size), do: []

  defp filter_ingest_versions(params, [_h | _t] = permissions, page, size) do
    user_defined_filters = create_filters(params)

    filter = permissions |> create_filter_clause(user_defined_filters)

    query = create_query(params, filter)
    sort = Map.get(params, "sort", ["_score", "name.raw"])

    %{from: page * size, size: size, query: query, sort: sort}
    |> do_search
  end

  defp create_query(%{ingest_id: id}) do
    %{term: %{ingest_id: id}}
  end

  defp create_query(%{"query" => query}) do
    equery = Query.add_query_wildcard(query)

    %{simple_query_string: %{query: equery}}
    |> bool_query
  end

  defp create_query(_params) do
    %{match_all: %{}}
    |> bool_query
  end

  defp create_query(%{"query" => query}, filter) do
    equery = Query.add_query_wildcard(query)

    %{simple_query_string: %{query: equery}}
    |> bool_query(filter)
  end

  defp create_query(_params, filter) do
    %{match_all: %{}}
    |> bool_query(filter)
  end

  defp bool_query(query, filter) do
    %{bool: %{must: query, filter: filter}}
  end

  defp bool_query(query) do
    %{bool: %{must: query}}
  end

  defp create_filter_clause(permissions, user_defined_filters) do
    should_clause =
      permissions
      |> Enum.map(&entry_to_filter_clause(&1, user_defined_filters))

    %{bool: %{should: should_clause}}
  end

  defp entry_to_filter_clause(
         %{resource_id: resource_id, permissions: permissions},
         user_defined_filters
       ) do
    domain_clause = %{term: %{domain_ids: resource_id}}

    status =
      @permissions_to_status
      |> Map.take(permissions)
      |> Map.values()

    status_clause = %{terms: %{status: status}}

    %{
      bool: %{filter: user_defined_filters ++ [domain_clause, status_clause]}
    }
  end

  defp do_search(search) do
    %{results: results, total: total} = Search.search(search)
    results = results |> Enum.map(&Map.get(&1, "_source"))
    %{results: results, total: total}
  end
end
