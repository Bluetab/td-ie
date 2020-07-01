defmodule TdIeWeb.IngestLinkController do
  use TdIeWeb, :controller
  use TdHypermedia, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdIe.Ingests.Links

  require Logger

  action_fallback(TdIeWeb.FallbackController)

  swagger_path :delete do
    description("Delete a Link")
    produces("application/json")

    parameters do
      id(:path, :integer, "Link Id", required: true)
    end

    response(202, "Accepted")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns[:current_user]

    with {:ok, link} <- Links.get(id),
         {:can, true} <- {:can, can?(user, delete(link))},
         {:ok, _} <- Links.delete(id) do
      send_resp(conn, :accepted, "")
    end
  end

  def create_link(conn, _params) do
    # This method is only used to generate an action in the ingest_version hypermedia response
    send_resp(conn, :accepted, "")
  end
end
