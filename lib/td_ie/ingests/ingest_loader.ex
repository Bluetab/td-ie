defmodule TdIe.IngestLoader do
  @moduledoc """
  GenServer to load ingests into Redis
  """

  use GenServer

  alias TdCache.IngestCache
  alias TdIe.Ingests
  alias TdIe.Search.IndexWorker

  require Logger

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def refresh(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:refresh, ids})
  end

  def refresh(id) do
    refresh([id])
  end

  def delete(id) do
    GenServer.call(TdIe.IngestLoader, {:delete, id})
  end

  def ping(timeout \\ 5000) do
    GenServer.call(__MODULE__, :ping, timeout)
  end

  @impl true
  def init(state) do
    unless Application.get_env(:td_ie, :env) == :test do
      schedule_work(:load_ingest_cache, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:refresh, ids}, _from, state) do
    load_ingests(ids)
    IndexWorker.reindex(ids)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete, id}, _from, state) do
    IngestCache.delete(id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  @impl true
  def handle_info(:load_ingest_cache, state) do
    load_all_ingests()
    IndexWorker.reindex(:all)

    {:noreply, state}
  end

  defp schedule_work(action, seconds) do
    Process.send_after(self(), action, seconds)
  end

  defp load_ingests(ids) do
    ingests =
      ids
      |> Enum.map(&Ingests.get_currently_published_version!/1)
      |> Enum.map(&load_ingest_version_data/1)

    ingests
    |> load_ingest_data()
  end

  defp load_all_ingests do
    Ingests.list_all_ingests()
    |> Enum.map(& &1.id)
    |> load_ingests()
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
