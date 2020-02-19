defmodule TdIeWeb.SearchController do
  @moduledoc """
  Controller for search requests over elasticsearch
  """
  use TdIeWeb, :controller
  import Canada, only: [can?: 2]
  use PhoenixSwagger
  alias TdIe.Ingests.Ingest
  alias TdIe.Search.Indexer
  alias TdIeWeb.ErrorView

  swagger_path :reindex_all do
    description("Reindex all ES indexes with DB content")
    produces("application/json")
    response(200, "OK")
    response(403, "Unauthorized")
    response(500, "Client Error")
  end

  def reindex_all(conn, _params) do
    user = conn.assigns[:current_user]

    if can?(user, reindex_all(Ingest)) do
      :ok = Indexer.reindex(:all)
      send_resp(conn, :ok, "")
    else
      conn
      |> put_status(:forbidden)
      |> put_view(ErrorView)
      |> render("403.json")
    end
  end
end
