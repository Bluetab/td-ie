defmodule TdIe.Application do
  @moduledoc false

  use Application

  alias TdIeWeb.Endpoint

  def start(_type, _args) do
    children = [
      TdIe.Repo,
      TdIeWeb.Endpoint,
      TdIe.Search.Cluster,
      TdIe.Search.IndexWorker,
      TdIe.Cache.IngestLoader,
      TdIe.Cache.DomainEventConsumer,
      TdIe.Scheduler
    ]

    opts = [strategy: :one_for_one, name: TdIe.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end
end
