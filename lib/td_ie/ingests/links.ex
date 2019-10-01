defmodule TdIe.Ingests.Links do
  @moduledoc """
  The Ingest Links context.
  """

  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestVersion
  alias TdCache.LinkCache

  def get(id) do
    LinkCache.get(id)
  end

  def delete(id) do
    LinkCache.delete(id)
  end

  def get_links(%IngestVersion{ingest_id: ingest_id}) do
    get_links(ingest_id)
  end

  def get_links(%Ingest{id: id}), do: get_links(id)

  def get_links(ingest_id) when is_integer(ingest_id) do
    case LinkCache.list("ingest", ingest_id) do
      {:ok, links} -> links
      _ -> []
    end
  end
end
