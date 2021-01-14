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
    claims = conn.assigns[:current_resource]
    filters = Search.get_filter_values(claims, %{})
    render(conn, "show.json", filters: filters)
  end

  swagger_path :search do
    description("List Ingest Filters")
    response(200, "OK", Schema.ref(:FilterResponse))
  end

  def search(conn, params) do
    claims = conn.assigns[:current_resource]
    filters = Search.get_filter_values(claims, params)
    render(conn, "show.json", filters: filters)
  end
end
