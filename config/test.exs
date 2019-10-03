use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_ie, TdIeWeb.Endpoint,
  http: [port: 4014],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :td_ie, TdIe.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "td_ie_test",
  hostname: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox

config :td_ie, permission_resolver: TdIe.Permissions.MockPermissionResolver

config :td_ie, TdIe.Search.Cluster, api: TdIe.ElasticsearchMock

config :td_ie, :audit_service,
  api_service: TdIeWeb.ApiServices.MockTdAuditService,
  audit_host: "localhost",
  audit_port: "4007",
  audit_domain: ""

config :td_cache, redis_host: "redis"
