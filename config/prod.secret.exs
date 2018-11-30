use Mix.Config

# In this file, we keep production configuration that
# you'll likely want to automate and keep away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or yourself later on).
config :td_ie, TdIeWeb.Endpoint,
  secret_key_base: "Fyg/OjjnUqRRS/jMOMJ3oL3BqxJpyyDE+ix0+QfjFuiFBdM9hTnhrV3qLQDPGuYh"

# Configure your database
config :td_ie, TdIe.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "${DB_USER}",
  password: "${DB_PASSWORD}",
  database: "${DB_NAME}",
  hostname: "${DB_HOST}"
  pool_size: 10

config :td_ie, TdIe.Auth.Guardian,
  allowed_algos: ["HS512"], # optional
  issuer: "tdauth",
  ttl: { 1, :hours },
  secret_key: "${GUARDIAN_SECRET_KEY}"

config :td_ie, :audit_service, api_service: TdIeWeb.ApiServices.HttpTdAuditService,
  audit_host: "${API_AUDIT_HOST}",
  audit_port: "${API_AUDIT_PORT}",
  audit_domain: ""

config :td_ie, :elasticsearch,
  search_service: TdIe.Search,
  es_host: "${ES_HOST}",
  es_port: "${ES_PORT}",
  type_name: "doc"

config :td_perms, redis_host: "${REDIS_HOST}"
