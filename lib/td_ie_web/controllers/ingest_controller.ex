defmodule TdIeWeb.IngestController do
  @moduledoc """
  Controller for ingest requests
  """
  use TdHypermedia, :controller
  use TdIeWeb, :controller

  import Canada, only: [can?: 2]

  alias TdCache.TemplateCache
  alias TdIe.Ingests
  alias TdIe.Ingests.IngestVersion
  alias TdIe.Ingests.Workflow
  alias TdIeWeb.ErrorView
  alias TdIeWeb.IngestSupport

  require Logger

  action_fallback(TdIeWeb.FallbackController)

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

  def update(conn, %{"id" => id, "ingest" => ingest_params}) do
    %{user_id: user_id} = claims = conn.assigns[:current_resource]

    ingest_version = Ingests.get_current_version_by_ingest_id!(id)

    ingest_type = ingest_version.ingest.type
    ingest_name = Map.get(ingest_params, "name")
    %{:content => content_schema} = TemplateCache.get_by_name!(ingest_type)

    ingest_attrs =
      %{}
      |> Map.put("last_change_by", user_id)
      |> Map.put("last_change_at", DateTime.utc_now())

    update_params =
      ingest_params
      |> Map.put("ingest", ingest_attrs)
      |> Map.put("content_schema", content_schema)
      |> Map.update("content", %{}, & &1)
      |> Map.put("last_change_by", user_id)
      |> Map.put("last_change_at", DateTime.utc_now())
      |> Map.put("in_progress", ingest_version.in_progress)

    with {:can, true} <- {:can, can?(claims, update(ingest_version))},
         :ok <- Ingests.check_ingest_name_availability(ingest_type, ingest_name, id),
         {:ok, %IngestVersion{} = ingest} <-
           Workflow.update_ingest_version(ingest_version, update_params) do
      render(conn, "show.json", ingest: ingest)
    else
      error ->
        IngestSupport.handle_ingest_errors(conn, error)
    end
  end

  def update_status(conn, %{
        "ingest_id" => id,
        "ingest" => %{"status" => new_status} = params
      }) do
    claims = conn.assigns[:current_resource]

    ingest_version = Ingests.get_current_version_by_ingest_id!(id)
    status = ingest_version.status

    case {status, new_status} do
      {"draft", "pending_approval"} ->
        send_for_approval(conn, claims, ingest_version, params)

      {"pending_approval", "published"} ->
        publish(conn, claims, ingest_version, params)

      {"pending_approval", "rejected"} ->
        reject(conn, claims, ingest_version, params)

      {"rejected", "pending_approval"} ->
        send_for_approval(conn, claims, ingest_version, params)

      {"rejected", "draft"} ->
        undo_rejection(conn, claims, ingest_version, params)

      {"published", "deprecated"} ->
        deprecate(conn, claims, ingest_version, params)

      {"published", "draft"} ->
        do_version(conn, claims, ingest_version, params)

      _ ->
        Logger.info("No status action for {#{status}, #{new_status}} combination")

        conn |> put_status(:unprocessable_entity) |> put_view(ErrorView) |> render("422.json")
    end
  end

  defp send_for_approval(conn, claims, ingest_version, _ingest_params) do
    with {:can, true} <- {:can, can?(claims, send_for_approval(ingest_version))},
         {:ok, %{updated: ingest}} <- Workflow.submit_ingest_version(ingest_version, claims) do
      render(conn, "show.json", ingest: ingest)
    end
  end

  defp reject(conn, claims, ingest_version, ingest_params) do
    reason = Map.get(ingest_params, "reject_reason")

    with {:can, true} <- {:can, can?(claims, reject(ingest_version))},
         {:ok, %{rejected: ingest}} <-
           Workflow.reject_ingest_version(ingest_version, reason, claims) do
      render(conn, "show.json", ingest: ingest)
    end
  end

  defp undo_rejection(conn, claims, ingest_version, _ingest_params) do
    with {:can, true} <- {:can, can?(claims, undo_rejection(ingest_version))},
         {:ok, %{updated: ingest}} <-
           Workflow.undo_rejected_ingest_version(ingest_version, claims) do
      render(conn, "show.json", ingest: ingest)
    end
  end

  defp publish(conn, claims, ingest_version, _ingest_params) do
    with {:can, true} <- {:can, can?(claims, publish(ingest_version))},
         {:ok, %{published: %IngestVersion{} = ingest}} <-
           Workflow.publish_ingest_version(ingest_version, claims) do
      render(conn, "show.json", ingest: ingest)
    end
  end

  defp deprecate(conn, claims, ingest_version, _ingest_params) do
    with {:can, true} <- {:can, can?(claims, deprecate(ingest_version))},
         {:ok, %{updated: ingest}} <- Workflow.deprecate_ingest_version(ingest_version, claims) do
      render(conn, "show.json", ingest: ingest)
    end
  end

  defp do_version(conn, claims, ingest_version, _ingest_params) do
    with {:can, true} <- {:can, can?(claims, version(ingest_version))},
         {:ok, %{current: %IngestVersion{} = new_version}} <-
           Workflow.new_ingest_version(ingest_version, claims) do
      conn
      |> put_status(:created)
      |> render("show.json", ingest: new_version)
    end
  end

  def index_status(conn, status) do
    claims = conn.assigns[:current_resource]
    ingests = build_list(claims, status)

    render(conn, "index.json", ingests: ingests, hypermedia: hypermedia("ingest", conn, ingests))
  end

  defp build_list(claims, %{"status" => status}) do
    list_ingest = Ingests.list_all_ingest_with_status([status])

    case status do
      "draft" -> []
      "pending_approval" -> filter_list(claims, list_ingest)
      "rejected" -> []
      "published" -> []
      "versioned" -> []
      "deprecated" -> []
    end
  end

  defp filter_list(claims, list_ingest) do
    Enum.reduce(list_ingest, [], fn ingest, acc ->
      if can?(claims, publish(ingest)) or can?(claims, reject(ingest)) do
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
