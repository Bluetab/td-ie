defmodule TdIe.Application do
  @moduledoc false

  use Application
  alias TdIeWeb.Endpoint
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(TdIe.Repo, []),
      # Start the endpoint when the application starts
      supervisor(TdIeWeb.Endpoint, []),
      # Start your own worker by calling: TdIe.Worker.start_link(arg1, arg2, arg3)
      # worker(TdIe.Worker, [arg1, arg2, arg3]),
      # Elasticsearch worker
      TdIe.Search.Cluster,
      worker(TdIe.Search.IndexWorker, [TdIe.Search.IndexWorker]),
      worker(TdIe.IngestLoader, [TdIe.IngestLoader])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
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
