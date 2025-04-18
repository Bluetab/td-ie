# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# Environment
config :td_ie, :env, Mix.env()
config :td_cluster, :env, Mix.env()
config :td_cluster, groups: [:ie]
config :td_core, :env, Mix.env()

# General application configuration
config :td_ie,
  ecto_repos: [TdIe.Repo]

# Configures the endpoint
config :td_ie, TdIeWeb.Endpoint,
  http: [port: 4014],
  url: [host: "localhost"],
  render_errors: [view: TdIeWeb.ErrorView, accepts: ~w(json)]

# Configures Elixir's Logger
# set EX_LOGGER_FORMAT environment variable to override Elixir's Logger format
# (without the 'end of line' character)
# EX_LOGGER_FORMAT='$date $time [$level] $message'
config :logger, :console,
  format:
    (System.get_env("EX_LOGGER_FORMAT") || "$date\T$time\Z [$level] $metadata$message") <> "\n",
  level: :info,
  metadata: [:pid, :module],
  utc_log: true

# Configuration for Phoenix
config :phoenix, :json_library, Jason

config :td_ie, TdIe.Auth.Guardian,
  allowed_algos: ["HS512"],
  issuer: "tdauth",
  ttl: {1, :hours},
  secret_key: "SuperSecretTruedat"

config :td_ie, TdIe.Repo, pool_size: 4

config :td_cache, :audit,
  service: "td_ie",
  stream: "audit:events"

config :td_cache, :event_stream,
  consumer_id: "default",
  consumer_group: "ie",
  streams: [
    [key: "template:events", consumer: TdCore.Search.IndexWorker]
  ]

config :td_ie, TdIe.Scheduler,
  jobs: [
    [
      schedule: "@daily",
      task: {TdCore.Search.IndexWorker, :reindex, [:ingests, :all]},
      run_strategy: Quantum.RunStrategy.Local
    ],
    [
      schedule: "@reboot",
      task: {TdIe.Jobs.UpdateDomainFields, :run, []},
      run_strategy: Quantum.RunStrategy.Local
    ]
  ]

# Import Elasticsearch config
import_config "elastic.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
