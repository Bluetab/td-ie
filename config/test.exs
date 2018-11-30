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
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :td_ie, df_cache: TdPerms.MockDynamicFormCache
config :td_ie, permission_resolver: TdIe.Permissions.MockPermissionResolver

config :td_ie, :elasticsearch,
  search_service: TdIe.Search.MockSearch,
  es_host: "localhost",
  es_port: 9200,
  type_name: "doc"

config :td_ie, :audit_service, api_service: TdIeWeb.ApiServices.MockTdAuditService,
  audit_host: "localhost",
  audit_port: "4007",
  audit_domain: ""

config :td_perms, redis_host: "localhost"
