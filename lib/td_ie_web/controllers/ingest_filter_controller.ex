defmodule TdIeWeb.IngestFilterController do
  @moduledoc """
  Controller for ingest filters in elasticsearch
  """
  require Logger
  use TdIeWeb, :controller
  use PhoenixSwagger

  alias TdIe.Ingest.Search
  alias TdIeWeb.SwaggerDefinitions

  action_fallback(TdIeWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.filter_swagger_definitions()
  end

  swagger_path :index do
    description("List Ingest Filters")
    response(200, "OK", Schema.ref(:FilterResponse))
  end

  def index(conn, _params) do
    user = conn.assigns[:current_user]
    filters = Search.get_filter_values(user)
    render(conn, "show.json", filters: filters)
  end
end
