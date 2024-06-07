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

config :td_core, TdCore.Search.Cluster,
  # If the variable delete_existing_index is set to false,
  # it will not be deleted in the case that there is no index in the hot swap process."
  delete_existing_index: System.get_env("DELETE_EXISTING_INDEX", "true") |> String.to_atom(),
  default_options: [
    timeout: System.get_env("ES_TIMEOUT", "5000") |> String.to_integer(),
    recv_timeout: System.get_env("ES_RECV_TIMEOUT", "40000") |> String.to_integer()
  ],
  default_settings: %{
    "number_of_shards" => System.get_env("ES_SHARDS", "1") |> String.to_integer(),
    "number_of_replicas" => System.get_env("ES_REPLICAS", "1") |> String.to_integer(),
    "refresh_interval" => System.get_env("ES_REFRESH_INTERVAL", "5s"),
    "max_result_window" => System.get_env("ES_MAX_RESULT_WINDOW", "10000") |> String.to_integer(),
    "index.indexing.slowlog.threshold.index.warn" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_WARN", "10s"),
    "index.indexing.slowlog.threshold.index.info" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_INFO", "5s"),
    "index.indexing.slowlog.threshold.index.debug" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_DEBUG", "2s"),
    "index.indexing.slowlog.threshold.index.trace" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_TRACE", "500ms"),
    "index.indexing.slowlog.level" => System.get_env("ES_INDEXING_SLOWLOG_LEVEL", "info"),
    "index.indexing.slowlog.source" => System.get_env("ES_INDEXING_SLOWLOG_SOURCE", "1000"),
    "index.mapping.total_fields.limit" => System.get_env("ES_MAPPING_TOTAL_FIELDS_LIMIT", "3000")
  }

config :td_core, TdCore.Search.Cluster,
  indexes: [
    ingests: [
      # When indexing data using the `mix elasticsearch.build` task,
      # control the data ingestion rate by raising or lowering the number
      # of items to send in each bulk request.
      bulk_page_size: System.get_env("BULK_PAGE_SIZE_INGESTS", "1000") |> String.to_integer()
    ]
  ]

config :td_core, TdCore.Search.Cluster,
  aggregations: %{
    "user" => System.get_env("AGG_USER_SIZE", "500") |> String.to_integer(),
    "domain" => System.get_env("AGG_DOMAIN_SIZE", "500") |> String.to_integer(),
    "system" => System.get_env("AGG_SYSTEM_SIZE", "500") |> String.to_integer(),
    "default" => System.get_env("AGG_DEFAULT_SIZE", "500") |> String.to_integer(),
    "domain_id" => System.get_env("AGG_DOMAIN_ID_SIZE", "500") |> String.to_integer(),
    "ingest_id" => System.get_env("AGG_INGEST_ID_SIZE", "500") |> String.to_integer(),
    "status" => System.get_env("AGG_STATUS_SIZE", "500") |> String.to_integer(),
    "current" => System.get_env("AGG_CURRENT_SIZE", "500") |> String.to_integer(),
    "in_progress" => System.get_env("AGG_IN_PROGRESS_SIZE", "500") |> String.to_integer(),
    "template" => System.get_env("AGG_TEMPLATE_SIZE", "500") |> String.to_integer(),
    "execution_status" =>
      System.get_env("AGG_EXECUTION_STATUS_SIZE", "500") |> String.to_integer(),
    "taxonomy" => System.get_env("AGG_TAXONOMY_SIZE", "500") |> String.to_integer(),
    "hierarchy" => System.get_env("AGG_HIERARCHY_SIZE", "500") |> String.to_integer()
  }
