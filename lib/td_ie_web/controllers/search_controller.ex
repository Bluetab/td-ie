defmodule TdIeWeb.SearchController do
  @moduledoc """
  Controller for search requests over elasticsearch
  """
  use TdIeWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdIe.Ingests.Ingest
  alias TdIe.Search.Indexer

  swagger_path :reindex_all do
    description("Reindex all ES indexes with DB content")
    produces("application/json")
    response(200, "OK")
    response(403, "Unauthorized")
    response(500, "Client Error")
  end

  def reindex_all(conn, _params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, reindex_all(Ingest))},
         :ok <- Indexer.reindex(:all) do
      send_resp(conn, :ok, "")
    end
  end
end
