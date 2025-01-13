defmodule TdIeWeb.IngestFilterController do
  @moduledoc """
  Controller for ingest filters in elasticsearch
  """
  require Logger
  use TdIeWeb, :controller

  alias TdIe.Ingests.Search

  action_fallback(TdIeWeb.FallbackController)

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]
    filters = Search.get_filter_values(claims, %{})
    render(conn, "show.json", filters: filters)
  end

  def search(conn, params) do
    claims = conn.assigns[:current_resource]
    filters = Search.get_filter_values(claims, params)
    render(conn, "show.json", filters: filters)
  end
end
