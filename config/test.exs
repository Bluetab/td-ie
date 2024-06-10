import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_ie, TdIeWeb.Endpoint, server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Track all Plug compile-time dependencies
config :phoenix, :plug_init_mode, :runtime

# Configure your database
config :td_ie, TdIe.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "td_ie_test",
  hostname: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1

config :td_core, TdCore.Search.Cluster, api: ElasticsearchMock
config :td_core, TdCore.Search.IndexWorker, TdCore.Search.IndexWorkerMock

config :td_cache, :audit, stream: "audit:events:test"
config :td_cache, redis_host: "redis", port: 6380
