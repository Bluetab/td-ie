defmodule TdIe.Ingests.Search.Query do
  @moduledoc """
  Support for building business concept search queries.
  """

  import TdIe.Search.Query,
    only: [term: 2, must: 2, must_not: 2, should: 2, bool_query: 1]

  alias TdIe.Ingests.Search.Aggregations
  alias TdIe.Ingests.Search.Filters

  @match_all %{match_all: %{}}
  @match_none %{match_none: %{}}

  @permissions_to_status %{
    "view_draft_ingests" => "draft",
    "view_deprecated_ingests" => "deprecated",
    "view_approval_pending_ingests" => "pending_approval",
    "view_published_ingests" => "published",
    "view_rejected_ingests" => "rejected",
    "view_versioned_ingests" => "versioned"
  }

  def build_filters(%{} = permissions) do
    permissions
    |> status_filter()
    |> List.wrap()
  end

  def status_filter(%{} = permissions) do
    @permissions_to_status
    |> Map.keys()
    |> Enum.map(&{Map.get(permissions, &1, :none), &1})
    |> Enum.group_by(
      fn {scope, _} -> scope end,
      fn {_, permission} -> Map.get(@permissions_to_status, permission) end
    )
    |> do_status_filter()
  end

  defp do_status_filter(%{} = permissions_by_scope) when map_size(permissions_by_scope) <= 1 do
    case Enum.at(permissions_by_scope, 0) do
      nil ->
        @match_none

      {:none, _statuses} ->
        @match_none

      {:all, _statuses} ->
        @match_all

      {domain_ids, statuses} ->
        [
          term("status", statuses),
          term("domain_ids", domain_ids)
        ]
    end
  end

  defp do_status_filter(permissions_by_scope) when map_size(permissions_by_scope) > 1 do
    permissions_by_scope
    # :all < list < :none
    |> Enum.sort_by(fn
      {:all, _} -> 1
      {:none, _} -> 3
      _list -> 2
    end)
    |> Enum.reduce(%{}, fn
      {:all, statuses}, acc ->
        should(acc, term("status", statuses))

      {:none, _statuses}, acc when map_size(acc) > 0 ->
        # We can avoid a must_not clause if any other status clause exists
        acc

      {:none, statuses}, acc ->
        must_not(acc, term("status", statuses))

      {domain_ids, statuses}, acc ->
        bool = %{
          filter: [
            term("status", statuses),
            term("domain_ids", domain_ids)
          ]
        }

        should(acc, %{bool: bool})
    end)
    |> maybe_bool_query()
  end

  defp maybe_bool_query(%{should: [single_clause]} = bool) when map_size(bool) == 1,
    do: single_clause

  defp maybe_bool_query(%{} = bool) when map_size(bool) >= 1, do: %{bool: bool}

  def build_query(filters, %{"must" => _} = params) do
    query = Map.get(params, "query")

    params
    |> Map.take(["must", "query"])
    |> Enum.reduce(%{must: filters}, &reduce_query/2)
    |> add_query_should(query)
    |> bool_query()
  end

  def build_query(filters, params) do
    params
    |> Map.take(["filters", "query"])
    |> Enum.reduce(%{filter: filters}, &reduce_query/2)
    |> bool_query()
  end

  defp add_query_should(filters, nil), do: filters

  defp add_query_should(filters, query) do
    should = [
      %{
        multi_match: %{
          query: maybe_wildcard(query),
          type: "best_fields",
          operator: "or"
        }
      }
    ]

    Map.put(filters, :should, should)
  end

  defp reduce_query({"filters", %{} = user_filters}, %{filter: filters} = acc)
       when map_size(user_filters) > 0 do
    %{acc | filter: merge_filters(filters, user_filters)}
  end

  defp reduce_query({"filters", %{}}, %{} = acc) do
    acc
  end

  defp reduce_query({"must", %{} = user_filters}, %{must: filters} = acc)
       when map_size(user_filters) > 0 do
    %{acc | must: merge_filters(filters, user_filters)}
  end

  defp reduce_query({"must", %{}}, %{} = acc) do
    acc
  end

  defp reduce_query({"query", query}, acc) do
    must(acc, %{simple_query_string: %{query: maybe_wildcard(query)}})
  end

  defp merge_filters(filters, user_filters) do
    aggs = Aggregations.aggregations()

    case Enum.uniq(filters ++ Filters.build_filters(user_filters, aggs)) do
      [_, _ | _] = filters -> Enum.reject(filters, &(&1 == %{match_all: %{}}))
      filters -> filters
    end
  end

  defp maybe_wildcard(query) do
    case String.last(query) do
      nil -> query
      "\"" -> query
      ")" -> query
      " " -> query
      _ -> "#{query}*"
    end
  end
end
