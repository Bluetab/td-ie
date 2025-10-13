defmodule TdIe.CacheConfigTest do
  use ExUnit.Case

  setup do
    original_audit_config = Application.get_env(:td_cache, :audit, [])
    original_event_stream_config = Application.get_env(:td_cache, :event_stream, [])

    on_exit(fn ->
      Application.put_env(:td_cache, :audit, original_audit_config)
      Application.put_env(:td_cache, :event_stream, original_event_stream_config)
    end)

    :ok
  end

  describe "td-cache configuration from environment variables" do
    test "reads REDIS_AUDIT_STREAM_MAXLEN from environment" do
      System.put_env("REDIS_AUDIT_STREAM_MAXLEN", "190")

      Application.put_env(:td_cache, :audit,
        service: "td_ie",
        stream: "audit:events",
        maxlen: System.get_env("REDIS_AUDIT_STREAM_MAXLEN", "100")
      )

      audit_config = Application.get_env(:td_cache, :audit)
      assert Keyword.get(audit_config, :maxlen) == "190"

      System.delete_env("REDIS_AUDIT_STREAM_MAXLEN")
    end

    test "reads REDIS_STREAM_MAXLEN from environment" do
      System.put_env("REDIS_STREAM_MAXLEN", "240")

      Application.put_env(:td_cache, :event_stream,
        consumer_id: "default",
        consumer_group: "ie",
        maxlen: System.get_env("REDIS_STREAM_MAXLEN", "100"),
        streams: []
      )

      event_stream_config = Application.get_env(:td_cache, :event_stream)
      assert Keyword.get(event_stream_config, :maxlen) == "240"

      System.delete_env("REDIS_STREAM_MAXLEN")
    end

    test "uses default values when environment variables are not set" do
      System.delete_env("REDIS_AUDIT_STREAM_MAXLEN")
      System.delete_env("REDIS_STREAM_MAXLEN")

      Application.put_env(:td_cache, :audit,
        service: "td_ie",
        stream: "audit:events",
        maxlen: System.get_env("REDIS_AUDIT_STREAM_MAXLEN", "100")
      )

      Application.put_env(:td_cache, :event_stream,
        maxlen: System.get_env("REDIS_STREAM_MAXLEN", "100"),
        streams: []
      )

      audit_config = Application.get_env(:td_cache, :audit)
      event_stream_config = Application.get_env(:td_cache, :event_stream)

      assert Keyword.get(audit_config, :maxlen) == "100"
      assert Keyword.get(event_stream_config, :maxlen) == "100"
    end

    test "configuration preserves ingest indexing consumer" do
      System.put_env("REDIS_STREAM_MAXLEN", "380")

      Application.put_env(:td_cache, :event_stream,
        consumer_id: "default",
        consumer_group: "ie",
        maxlen: System.get_env("REDIS_STREAM_MAXLEN", "100"),
        streams: [
          [key: "ingest:events", consumer: TdCore.Search.IndexWorker]
        ]
      )

      event_stream_config = Application.get_env(:td_cache, :event_stream)

      assert Keyword.get(event_stream_config, :maxlen) == "380"
      assert Keyword.get(event_stream_config, :consumer_group) == "ie"

      streams = Keyword.get(event_stream_config, :streams)
      assert length(streams) == 1

      ingest_stream = Enum.find(streams, &(Keyword.get(&1, :key) == "ingest:events"))
      assert Keyword.get(ingest_stream, :consumer) == TdCore.Search.IndexWorker

      System.delete_env("REDIS_STREAM_MAXLEN")
    end
  end
end
