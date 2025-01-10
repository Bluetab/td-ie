defmodule TdIe.Ingests.Search.Query do
  @moduledoc """
  Support for building business concept search queries.
  """

  import TdCore.Search.Query,
    only: [term_or_terms: 2, must_not: 2, should: 2]

  alias TdCore.Search.Query

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
          term_or_terms("status", statuses),
          term_or_terms("domain_ids", domain_ids)
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
        should(acc, term_or_terms("status", statuses))

      {:none, _statuses}, acc when map_size(acc) > 0 ->
        # We can avoid a must_not clause if any other status clause exists
        acc

      {:none, statuses}, acc ->
        must_not(acc, term_or_terms("status", statuses))

      {domain_ids, statuses}, acc ->
        bool = %{
          filter: [
            term_or_terms("status", statuses),
            term_or_terms("domain_ids", domain_ids)
          ]
        }

        should(acc, %{bool: bool})
    end)
    |> maybe_bool_query()
  end

  defp maybe_bool_query(%{should: [single_clause]} = bool) when map_size(bool) == 1,
    do: single_clause

  defp maybe_bool_query(%{} = bool) when map_size(bool) >= 1, do: %{bool: bool}

  def build_query(filters, params, query_data) do
    opts = query_data |> with_search_clauses() |> Keyword.new()
    Query.build_query(filters, params, opts)
  end

  defp with_search_clauses(%{fields: fields} = query_data) do
    multi_match_bool_prefix = %{
      multi_match: %{
        type: "bool_prefix",
        fields: fields,
        fuzziness: "AUTO",
        lenient: true,
        fuzzy_transpositions: true
      }
    }

    query_data
    |> Map.take([:aggs])
    |> Map.put(:clauses, [multi_match_bool_prefix])
  end
end
