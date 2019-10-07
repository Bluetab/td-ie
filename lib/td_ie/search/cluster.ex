defmodule TdIe.Search.Cluster do
  @moduledoc "Elasticsearch cluster configuration for TdIe"

  use Elasticsearch.Cluster, otp_app: :td_ie
end
