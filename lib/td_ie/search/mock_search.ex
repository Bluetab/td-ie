defmodule TdIe.Search.MockSearch do
  @moduledoc false

  alias Jason, as: JSON
  alias TdIe.Ingests
  alias TdIe.Ingests.IngestVersion

  def put_search(_something) do
  end

  def delete_search(_something) do
  end

  def search("ingest", %{query: %{bool: %{must: %{match_all: %{}}}}}) do
    Ingests.list_all_ingest_versions()
    |> Enum.map(&IngestVersion.search_fields(&1))
    |> Enum.map(&%{_source: &1})
    |> JSON.encode!()
    |> JSON.decode!()
    |> search_results
  end

  def search("ingest", %{query: %{term: %{ingest_id: ingest_id}}}) do
    Ingests.list_all_ingest_versions()
    |> Enum.filter(&(&1.ingest_id == ingest_id))
    |> Enum.map(&IngestVersion.search_fields(&1))
    |> Enum.map(&%{_source: &1})
    |> JSON.encode!()
    |> JSON.decode!()
    |> search_results
  end

  def search("ingest", %{
        query: %{bool: %{must: %{simple_query_string: %{query: query}}}}
      }) do
    Ingests.list_all_ingest_versions()
    |> Enum.map(&IngestVersion.search_fields(&1))
    |> Enum.filter(&matches(&1, query))
    |> Enum.map(&%{_source: &1})
    |> JSON.encode!()
    |> JSON.decode!()
    |> search_results
  end

  defp search_results(results) do
    %{results: results, total: Enum.count(results)}
  end

  defp matches(string, query) when is_bitstring(string) do
    prefix = String.replace(query, "*", "")
    String.starts_with?(string, prefix)
  end

  defp matches(list, query) when is_list(list) do
    list |> Enum.any?(&matches(&1, query))
  end

  defp matches(map, query) when is_map(map) do
    map |> Map.values() |> matches(query)
  end

  defp matches(_item, _query), do: false

  def get_filters(_query) do
    %{
      "domain" => ["Domain 1", "Domain 2"],
      "dynamic_field" => ["Value 1", "Value 2"]
    }
  end
end
