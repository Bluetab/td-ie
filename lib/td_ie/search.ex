defmodule TdIe.Search do
  @moduledoc """
  Search Engine calls
  """

  alias TdCache.HierarchyCache
  alias TdCache.TaxonomyCache
  alias TdIe.Search.Cluster

  require Logger

  @index "ingests"

  def search(query) do
    response =
      Elasticsearch.post(Cluster, "/#{@index}/_search", query,
        params: %{"track_total_hits" => "true"}
      )

    case response do
      {:ok, %{"aggregations" => aggregations, "hits" => %{"hits" => results, "total" => total}}} ->
        %{results: results, total: get_total(total), aggregations: aggregations}

      {:ok, %{"hits" => %{"hits" => results, "total" => total}}} ->
        %{results: results, total: get_total(total), aggregations: %{}}

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  def get_filters(query) do
    response = Elasticsearch.post(Cluster, "/#{@index}/_search", query)

    case response do
      {:ok, %{"aggregations" => aggregations}} ->
        aggregations
        |> Map.to_list()
        |> Enum.into(%{}, &filter_values/1)

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  defp filter_values({"taxonomy", %{"buckets" => buckets}}) do
    domains =
      buckets
      |> Enum.flat_map(fn %{"key" => domain_id} ->
        TdCache.TaxonomyCache.reaching_domain_ids(domain_id)
      end)
      |> Enum.uniq()
      |> Enum.map(&get_domain/1)
      |> Enum.reject(&is_nil/1)

    {"taxonomy", domains}
  end

  defp filter_values({name, %{"meta" => %{"type" => "domain"}, "buckets" => buckets}}) do
    domains =
      buckets
      |> Enum.map(fn %{"key" => domain_id} -> get_domain(domain_id) end)
      |> Enum.reject(&is_nil/1)

    {name, domains}
  end

  defp filter_values({name, %{"meta" => %{"type" => "hierarchy"}, "buckets" => buckets}}) do
    node_names =
      buckets
      |> Enum.map(fn %{"key" => key} -> get_hierarchy(key) end)
      |> Enum.reject(&is_nil/1)

    {name, node_names}
  end

  defp filter_values({name, %{"buckets" => buckets}}) do
    {name, buckets |> Enum.map(& &1["key"])}
  end

  defp filter_values({name, %{"distinct_search" => distinct_search}}) do
    filter_values({name, distinct_search})
  end

  defp filter_values({name, %{"doc_count" => 0}}), do: {name, []}

  defp get_domain(""), do: nil
  defp get_domain(id) when is_integer(id) or is_binary(id), do: TaxonomyCache.get_domain(id)
  defp get_domain(_), do: nil

  defp get_total(value) when is_integer(value), do: value
  defp get_total(%{"relation" => "eq", "value" => value}) when is_integer(value), do: value

  defp get_hierarchy(""), do: nil

  defp get_hierarchy(key) when is_binary(key) do
    [hierarchy_id, node_id] = String.split(key, "_")

    case HierarchyCache.get(hierarchy_id) do
      {:ok, %{nodes: nodes}} ->
        case Enum.find(nodes, &(Map.get(&1, "node_id") === String.to_integer(node_id))) do
          nil ->
            nil

          %{"name" => name} ->
            %{id: key, name: name}
        end

      _ ->
        nil
    end
  end

  defp get_hierarchy(_), do: nil
end
