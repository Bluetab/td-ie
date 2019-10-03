defmodule TdIe.Search do
  @moduledoc """
  Search Engine calls
  """

  alias Jason, as: JSON
  alias TdIe.ESClientApi
  alias TdIe.Ingests
  alias TdIe.Ingests.IngestVersion

  require Logger

  def put_bulk_search(:ingest) do
    # TODO
  end

  def put_search(%IngestVersion{} = ingest_version) do
    search_fields = ingest_version.__struct__.search_fields(ingest_version)

    response =
      ESClientApi.index_content(
        ingest_version.__struct__.index_name(),
        ingest_version.id,
        search_fields |> JSON.encode!()
      )

    case response do
      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.info("Ingest #{ingest_version.name} created/updated status #{status}")

      {:error, _error} ->
        Logger.error("ES: Error creating/updating ingest #{ingest_version.name}")
    end
  end

  def delete_search(%IngestVersion{} = ingest_version) do
    response = ESClientApi.delete_content("ingest", ingest_version.id)

    case response do
      {_, %HTTPoison.Response{status_code: 200}} ->
        Logger.info("Ingest #{ingest_version.name} deleted status 200")

      {_, %HTTPoison.Response{status_code: status_code}} ->
        Logger.error("ES: Error deleting ingest #{ingest_version.name} status #{status_code}")

      {:error, %HTTPoison.Error{reason: :econnrefused}} ->
        Logger.error("Error connecting to ES")
    end
  end

  def search(index_name, query) do
    query =
      query
      |> Map.put(:sort, ["name.raw"])

    Logger.debug(fn -> "Query: #{inspect(query)}" end)
    response = ESClientApi.search_es(index_name, query)

    case response do
      {:ok, %HTTPoison.Response{body: %{"hits" => %{"hits" => results, "total" => total}}}} ->
        %{results: results, total: total}

      {:ok, %HTTPoison.Response{body: error}} ->
        error
    end
  end

  def get_filters(query) do
    response = ESClientApi.search_es("ingest", query)

    case response do
      {:ok, %HTTPoison.Response{body: %{"aggregations" => aggregations}}} ->
        aggregations
        |> Map.to_list()
        |> Enum.into(%{}, &filter_values/1)

      {:ok, %HTTPoison.Response{body: error}} ->
        error
    end
  end

  defp filter_values({name, %{"buckets" => buckets}}) do
    {name, buckets |> Enum.map(& &1["key"])}
  end

  defp filter_values({name, %{"distinct_search" => distinct_search}}) do
    filter_values({name, distinct_search})
  end
end
