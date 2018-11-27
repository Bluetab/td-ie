defmodule TdIe.IngestLoader do
  @moduledoc """
  GenServer to load ingests into Redis
  """

  use GenServer

  alias TdIe.Ingests
  alias TdPerms.IngestCache

  require Logger

  @cache_ingests_on_startup Application.get_env(
                                       :td_ie,
                                       :cache_ingests_on_startup
                                     )

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def refresh(ingest_id) do
    GenServer.call(TdIe.IngestLoader, {:refresh, ingest_id})
  end

  def delete(ingest_id) do
    GenServer.call(TdIe.IngestLoader, {:delete, ingest_id})
  end

  @impl true
  def init(state) do
    if @cache_ingests_on_startup, do: schedule_work(:load_ingest_cache, 0)
    {:ok, state}
  end

  @impl true
  def handle_call({:refresh, ingest_id}, _from, state) do
    load_ingest(ingest_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete, ingest_id}, _from, state) do
    IngestCache.delete_ingest(ingest_id)
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

  defp load_ingest(ingest_id) do
    ingest =
      ingest_id
      |> Ingests.get_currently_published_version!()
      |> load_ingest_version_data()

    [ingest]
    |> load_ingest_data()
  end

  defp load_all_ingests do
    Ingests.list_all_ingests()
    |> Enum.map(& load_ingest(&1.id))
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
      |> Enum.map(&IngestCache.put_ingest(&1))
      |> Enum.map(fn {res, _} -> res end)

    if Enum.any?(results, &(&1 != :ok)) do
      Logger.warn("Cache loading of ingests failed")
    else
      Logger.info("Cached #{length(results)} ingests")
    end
  end
end
