import Config

config :td_ie, TdIe.Repo,
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASSWORD"),
  database: System.fetch_env!("DB_NAME"),
  hostname: System.fetch_env!("DB_HOST")

config :td_ie, TdIe.Auth.Guardian, secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY")

config :td_ie, TdIe.Search.Cluster, url: System.fetch_env!("ES_URL")

config :td_ie, :audit_service,
  audit_host: System.fetch_env!("API_AUDIT_HOST"),
  audit_port: System.fetch_env!("API_AUDIT_PORT")

config :td_cache, redis_host: System.fetch_env!("REDIS_HOST")

config :td_cache, :event_stream, consumer_id: System.fetch_env!("HOSTNAME")
