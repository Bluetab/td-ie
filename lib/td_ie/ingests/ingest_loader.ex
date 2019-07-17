defmodule TdIe.IngestLoader do
  @moduledoc """
  GenServer to load ingests into Redis
  """

  use GenServer

  alias TdCache.IngestCache
  alias TdIe.Ingests

  require Logger

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def refresh(id) do
    GenServer.call(TdIe.IngestLoader, {:refresh, id})
  end

  def delete(id) do
    GenServer.call(TdIe.IngestLoader, {:delete, id})
  end

  @impl true
  def init(state) do
    unless Application.get_env(:td_ie, :env) == :test do
      schedule_work(:load_ingest_cache, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:refresh, id}, _from, state) do
    load_ingest(id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete, id}, _from, state) do
    IngestCache.delete(id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:load_ingest_cache, state) do
    load_all_ingests()

    {:noreply, state}
  end

  defp schedule_work(action, seconds) do
    Process.send_after(self(), action, seconds)
  end

  defp load_ingest(id) do
    ingest =
      id
      |> Ingests.get_currently_published_version!()
      |> load_ingest_version_data()

    [ingest]
    |> load_ingest_data()
  end

  defp load_all_ingests do
    Ingests.list_all_ingests()
    |> Enum.map(&load_ingest(&1.id))
  end

  defp load_ingest_version_data(ingest_version) do
    %{
      id: ingest_version.ingest_id,
      domain_id: ingest_version.ingest.domain_id,
      name: ingest_version.name,
      ingest_version_id: ingest_version.id
    }
  end

  def load_ingest_data(ingests) do
    results =
      ingests
      |> Enum.map(&Map.take(&1, [:id, :domain_id, :name, :ingest_version_id]))
      |> Enum.map(&IngestCache.put/1)
      |> Enum.map(fn {res, _} -> res end)

    if Enum.any?(results, &(&1 != :ok)) do
      Logger.warn("Cache loading of ingests failed")
    else
      Logger.info("Cached #{length(results)} ingests")
    end
  end
end
