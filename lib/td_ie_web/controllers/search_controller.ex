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

    with true <- can?(user, reindex_all(Ingest)) do
      {:ok, _response} = Indexer.reindex(:ingest)
      send_resp(conn, :ok, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      _error ->
        conn
        |> put_status(:internal_server_error)
        |> render(ErrorView, "500.json")
    end
  end
end
