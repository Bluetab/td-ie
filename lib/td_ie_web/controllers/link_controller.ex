defmodule TdIeWeb.IngestLinkController do
  use TdIeWeb, :controller
  use TdHypermedia, :controller

  import Canada, only: [can?: 2]

  alias TdIe.Ingests.Links

  require Logger

  action_fallback(TdIeWeb.FallbackController)

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with {:ok, link} <- Links.get(id),
         {:can, true} <- {:can, can?(claims, delete(link))},
         {:ok, _} <- Links.delete(id) do
      send_resp(conn, :accepted, "")
    end
  end

  def create_link(conn, _params) do
    # This method is only used to generate an action in the ingest_version hypermedia response
    send_resp(conn, :accepted, "")
  end
end
