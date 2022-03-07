defmodule TdIe.Ingests.Search.Filters do
  @moduledoc """
  Functions for composing search query filters.
  """

  import TdIe.Search.Query, only: [term: 2]

  def build_filters(filters, aggs \\ %{}) do
    Enum.map(filters, &build_filter(&1, aggs))
  end

  defp build_filter({field, value_or_values}, _aggs) when field in ["domain_id", "ingest_id"] do
    term(field, value_or_values)
  end

  defp build_filter({key, values}, aggs) do
    aggs
    |> Map.get(key)
    |> build_filter(values, key)
  end

  defp build_filter(nil, values, field) do
    term(field, values)
  end

  defp build_filter(%{terms: %{field: field}}, values, _) do
    term(field, values)
  end

  defp build_filter(
         %{
           nested: %{path: path},
           aggs: %{distinct_search: distinct_search}
         },
         values,
         _
       ) do
    %{nested: %{path: path, query: build_nested_query(distinct_search, values)}}
  end

  defp build_nested_query(%{terms: %{field: field}}, values) do
    term(field, values)
  end
end
