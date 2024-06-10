defmodule TdIe.Search.Indexer do
  @moduledoc """
  Indexer for Ingests.
  """

  alias TdCore.Search.IndexWorker

  @index :ingests

  def reindex(ids) do
    IndexWorker.reindex(@index, ids)
  end

  def delete(ids) do
    IndexWorker.delete(@index, ids)
  end
end
