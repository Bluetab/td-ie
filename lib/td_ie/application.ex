defmodule TdIe.Application do
  @moduledoc false

  use Application

  alias TdCore.Search.IndexWorker
  alias TdIeWeb.Endpoint

  @impl true
  def start(_type, _args) do
    env = Application.get_env(:td_ie, :env)

    children =
      [
        TdIe.Repo,
        TdIeWeb.Endpoint
      ] ++ workers(env)

    opts = [strategy: :one_for_one, name: TdIe.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  defp workers(:test), do: []

  defp workers(_env) do
    [
      # Cluster
      TdCore.Search.Cluster,
      TdIe.Cache.IngestLoader,
      TdIe.Scheduler
    ] ++ IndexWorker.get_index_workers()
  end
end
