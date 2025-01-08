defmodule TdIeWeb.SearchController do
  @moduledoc """
  Controller for search requests over elasticsearch
  """
  use TdIeWeb, :controller

  import Canada, only: [can?: 2]

  alias TdIe.Ingests.Ingest
  alias TdIe.Search.Indexer

  def reindex_all(conn, _params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, reindex_all(Ingest))},
         :ok <- Indexer.reindex(:all) do
      send_resp(conn, :ok, "")
    end
  end
end
