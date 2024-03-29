import Config

if config_env() == :prod do
  config :td_ie, TdIe.Repo,
    username: System.fetch_env!("DB_USER"),
    password: System.fetch_env!("DB_PASSWORD"),
    database: System.fetch_env!("DB_NAME"),
    hostname: System.fetch_env!("DB_HOST"),
    port: System.get_env("DB_PORT", "5432") |> String.to_integer(),
    pool_size: System.get_env("DB_POOL_SIZE", "4") |> String.to_integer(),
    timeout: System.get_env("DB_TIMEOUT_MILLIS", "15000") |> String.to_integer(),
    ssl: System.get_env("DB_SSL", "") |> String.downcase() == "true",
    ssl_opts: [
      cacertfile: System.get_env("DB_SSL_CACERTFILE", ""),
      verify:
        System.get_env("DB_SSL_VERIFY", "verify_none") |> String.downcase() |> String.to_atom(),
      server_name_indication: System.get_env("DB_HOST") |> to_charlist(),
      certfile: System.get_env("DB_SSL_CLIENT_CERT", ""),
      keyfile: System.get_env("DB_SSL_CLIENT_KEY", ""),
      versions: [
        System.get_env("DB_SSL_VERSION", "tlsv1.2") |> String.downcase() |> String.to_atom()
      ]
    ]

  config :td_ie, TdIe.Auth.Guardian, secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY")

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

  config :td_cache,
    redis_host: System.fetch_env!("REDIS_HOST"),
    port: System.get_env("REDIS_PORT", "6379") |> String.to_integer(),
    password: System.get_env("REDIS_PASSWORD")

  config :td_cache, :event_stream, consumer_id: System.fetch_env!("HOSTNAME")

  config :td_core, TdCore.Search.Cluster, url: System.fetch_env!("ES_URL")

  with username when not is_nil(username) <- System.get_env("ES_USERNAME"),
       password when not is_nil(password) <- System.get_env("ES_PASSWORD") do
    config :td_core, TdCore.Search.Cluster,
      username: username,
      password: password
  end
end
