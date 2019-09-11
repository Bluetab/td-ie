defmodule TdIeWeb.IngestController do
  @moduledoc """
  Controller for ingest requests
  """
  use TdHypermedia, :controller
  use TdIeWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdCache.TemplateCache
  alias TdIe.Ingests
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestVersion
  alias TdIeWeb.ErrorView
  alias TdIeWeb.IngestSupport
  alias TdIeWeb.SwaggerDefinitions

  require Logger

  @search_service Application.get_env(:td_ie, :elasticsearch)[:search_service]

  action_fallback(TdIeWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.ingest_definitions()
  end

  swagger_path :index_children_ingest do
    description("List ingests children of Domain")
    produces("application/json")

    parameters do
      id(:path, :integer, "Domain ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestsResponse))
    response(400, "Client Error")
  end

  def index_children_ingest(conn, %{"domain_id" => id}) do
    ingest_versions = Ingests.get_domain_children_versions!(id)

    render(
      conn,
      "index.json",
      ingests: ingest_versions,
      hypermedia: hypermedia("ingest", conn, ingest_versions)
    )
  end

  def search(conn, %{} = search_params) do
    filter =
      Map.new()
      |> add_to_filter_as_int_list(:id, Map.get(search_params, "id"))
      |> add_to_filter_as_list(:status, Map.get(search_params, "status"))

    ingest_versions =
      if length(filter.id) > 0 do
        Ingests.find_ingest_versions(filter)
      else
        []
      end

    render(conn, "search.json", ingests: ingest_versions)
  end

  swagger_path :show do
    description("Show ingests")
    produces("application/json")

    parameters do
      id(:path, :integer, "ingest ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestResponse))
    response(400, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    ingest =
      id
      |> Ingests.get_current_version_by_ingest_id!()
      |> Ingests.with_domain()

    render(
      conn,
      "show.json",
      ingest: ingest,
      hypermedia: hypermedia("ingest", conn, ingest)
    )
  end

  swagger_path :update do
    description("Updates ingests")
    produces("application/json")

    parameters do
      ingest(:body, Schema.ref(:IngestUpdate), "ingest update attrs")
      id(:path, :integer, "ingest ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestResponse))
    response(400, "Client Error")
  end

  def update(conn, %{"id" => id, "ingest" => ingest_params}) do
    user = conn.assigns[:current_user]

    ingest_version = Ingests.get_current_version_by_ingest_id!(id)

    ingest_type = ingest_version.ingest.type
    ingest_name = Map.get(ingest_params, "name")
    %{:content => content_schema} = TemplateCache.get_by_name!(ingest_type)

    ingest_attrs =
      %{}
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now() |> DateTime.truncate(:second))

    update_params =
      ingest_params
      |> Map.put("ingest", ingest_attrs)
      |> Map.put("content_schema", content_schema)
      |> Map.update("content", %{}, & &1)
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now() |> DateTime.truncate(:second))
      |> Map.put("in_progress", ingest_version.in_progress)

    with true <- can?(user, update(ingest_version)),
         {:name_available} <-
           Ingests.check_ingest_name_availability(
             ingest_type,
             ingest_name,
             id
           ),
         {:ok, %IngestVersion{} = ingest} <-
           Ingests.update_ingest_version(
             ingest_version,
             update_params
           ) do
      @search_service.put_search(ingest_version)
      render(conn, "show.json", ingest: ingest)
    else
      error ->
        IngestSupport.handle_ingest_errors(conn, error)
    end
  end

  swagger_path :update_status do
    description("Updates Ingest status")
    produces("application/json")

    parameters do
      ingest(
        :body,
        Schema.ref(:IngestUpdateStatus),
        "ingest status update attrs"
      )

      ingest_id(:path, :integer, "ingest ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestResponse))
    response(400, "Client Error")
  end

  def update_status(conn, %{
        "ingest_id" => id,
        "ingest" => %{"status" => new_status} = ingest_params
      }) do
    user = conn.assigns[:current_user]

    ingest_version = Ingests.get_current_version_by_ingest_id!(id)
    status = ingest_version.status

    draft = Ingest.status().draft
    rejected = Ingest.status().rejected
    pending_approval = Ingest.status().pending_approval
    published = Ingest.status().published
    deprecated = Ingest.status().deprecated

    case {status, new_status} do
      {^draft, ^pending_approval} ->
        send_for_approval(conn, user, ingest_version, ingest_params)

      {^pending_approval, ^published} ->
        publish(conn, user, ingest_version, ingest_params)

      {^pending_approval, ^rejected} ->
        reject(conn, user, ingest_version, ingest_params)

      {^rejected, ^pending_approval} ->
        send_for_approval(conn, user, ingest_version, ingest_params)

      {^rejected, ^draft} ->
        undo_rejection(conn, user, ingest_version, ingest_params)

      {^published, ^deprecated} ->
        deprecate(conn, user, ingest_version, ingest_params)

      {^published, ^draft} ->
        do_version(conn, user, ingest_version, ingest_params)

      _ ->
        Logger.info("No status action for {#{status}, #{new_status}} combination")

        conn |> put_status(:unprocessable_entity) |> put_view(ErrorView) |> render("422.json")
    end
  end

  defp send_for_approval(conn, user, ingest_version, _ingest_params) do
    attrs = %{status: Ingest.status().pending_approval}

    with true <- can?(user, send_for_approval(ingest_version)),
         {:ok, %IngestVersion{} = ingest} <-
           Ingests.update_ingest_version_status(
             ingest_version,
             attrs
           ) do
      @search_service.put_search(ingest_version)
      render(conn, "show.json", ingest: ingest)
    else
      false ->
        conn |> put_status(:forbidden) |> put_view(ErrorView) |> render("403.json")

      _error ->
        conn |> put_status(:unprocessable_entity) |> put_view(ErrorView) |> render("422.json")
    end
  end

  defp reject(conn, user, ingest_version, ingest_params) do
    attrs = %{reject_reason: Map.get(ingest_params, "reject_reason")}

    with true <- can?(user, reject(ingest_version)),
         {:ok, %IngestVersion{} = ingest} <- Ingests.reject_ingest_version(ingest_version, attrs) do
      @search_service.put_search(ingest_version)
      render(conn, "show.json", ingest: ingest)
    else
      false ->
        conn |> put_status(:forbidden) |> put_view(ErrorView) |> render("403.json")

      _error ->
        conn |> put_status(:unprocessable_entity) |> put_view(ErrorView) |> render("422.json")
    end
  end

  defp undo_rejection(conn, user, ingest_version, _ingest_params) do
    attrs = %{status: Ingest.status().draft}

    with true <- can?(user, undo_rejection(ingest_version)),
         {:ok, %IngestVersion{} = ingest} <-
           Ingests.update_ingest_version_status(
             ingest_version,
             attrs
           ) do
      @search_service.put_search(ingest_version)
      render(conn, "show.json", ingest: ingest)
    else
      false ->
        conn |> put_status(:forbidden) |> put_view(ErrorView) |> render("403.json")

      _error ->
        conn |> put_status(:unprocessable_entity) |> put_view(ErrorView) |> render("422.json")
    end
  end

  defp publish(conn, user, ingest_version, _ingest_params) do
    with true <- can?(user, publish(ingest_version)),
         {:ok, %{published: %IngestVersion{} = ingest}} <-
           Ingests.publish_ingest_version(ingest_version) do
      render(conn, "show.json", ingest: ingest)
    else
      false ->
        conn |> put_status(:forbidden) |> put_view(ErrorView) |> render("403.json")

      _error ->
        conn |> put_status(:unprocessable_entity) |> put_view(ErrorView) |> render("422.json")
    end
  end

  defp deprecate(conn, user, ingest_version, _ingest_params) do
    attrs = %{status: Ingest.status().deprecated}

    with true <- can?(user, deprecate(ingest_version)),
         {:ok, %IngestVersion{} = ingest} <-
           Ingests.update_ingest_version_status(
             ingest_version,
             attrs
           ) do
      @search_service.put_search(ingest_version)
      render(conn, "show.json", ingest: ingest)
    else
      false ->
        conn |> put_status(:forbidden) |> put_view(ErrorView) |> render("403.json")

      _error ->
        conn |> put_status(:unprocessable_entity) |> put_view(ErrorView) |> render("422.json")
    end
  end

  defp do_version(conn, user, ingest_version, _ingest_params) do
    with true <- can?(user, version(ingest_version)),
         {:ok, %{current: %IngestVersion{} = new_version}} <-
           Ingests.new_ingest_version(user, ingest_version) do
      conn
      |> put_status(:created)
      |> render("show.json", ingest: new_version)
    else
      false ->
        conn |> put_status(:forbidden) |> put_view(ErrorView) |> render("403.json")

      _error ->
        conn |> put_status(:unprocessable_entity) |> put_view(ErrorView) |> render("422.json")
    end
  end

  swagger_path :index_status do
    description("List ingest with certain status")
    produces("application/json")

    parameters do
      status(:path, :string, "ingest Status", required: true)
    end

    response(200, "OK", Schema.ref(:IngestResponse))
    response(400, "Client Error")
  end

  def index_status(conn, status) do
    user = conn.assigns[:current_user]
    ingests = build_list(user, status)

    render(
      conn,
      "index.json",
      ingests: ingests,
      hypermedia: hypermedia("ingest", conn, ingests)
    )
  end

  defp build_list(user, %{"status" => status}) do
    list_ingest = Ingests.list_all_ingest_with_status([status])

    case status do
      "draft" ->
        []

      "pending_approval" ->
        filter_list(user, list_ingest)

      "rejected" ->
        []

      "published" ->
        []

      "versioned" ->
        []

      "deprecated" ->
        []
    end
  end

  defp filter_list(user, list_ingest) do
    Enum.reduce(list_ingest, [], fn ingest, acc ->
      if can?(user, publish(ingest)) or can?(user, reject(ingest)) do
        acc ++ [ingest]
      else
        []
      end
    end)
  end

  defp add_to_filter_as_int_list(filter, name, nil), do: Map.put(filter, name, [])

  defp add_to_filter_as_int_list(filter, name, value) do
    list_value =
      value
      |> String.split(",")
      |> Enum.map(&String.to_integer(String.trim(&1)))

    Map.put(filter, name, list_value)
  end

  defp add_to_filter_as_list(filter, name, nil), do: Map.put(filter, name, [])

  defp add_to_filter_as_list(filter, name, value) do
    list_value =
      value
      |> String.split(",")
      |> Enum.map(&String.trim(&1))

    Map.put(filter, name, list_value)
  end
end
