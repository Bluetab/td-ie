defmodule TdIe.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """

  alias Jason, as: JSON
  alias TdIe.ESClientApi
  alias TdIe.Search
  alias TdIe.Search.Mappings

  def reindex(:ingest) do
    ESClientApi.delete!("ingest")
    mapping = Mappings.get_mappings() |> JSON.encode!()
    %{status_code: 200} = ESClientApi.put!("ingest", mapping)
    Search.put_bulk_search(:ingest)
  end
end
