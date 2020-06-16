defmodule TdIeWeb.IngestVersionController do
  @moduledoc """
  Controller of Ingest version requests
  """

  use TdHypermedia, :controller
  use TdIeWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdCache.TemplateCache
  alias TdIe.Ingest.Download
  alias TdIe.Ingest.Search
  alias TdIe.Ingests
  alias TdIe.Ingests.IngestVersion
  alias TdIe.Ingests.Links
  alias TdIe.Ingests.Workflow
  alias TdIeWeb.ErrorView
  alias TdIeWeb.IngestSupport
  alias TdIeWeb.SwaggerDefinitions

  require Logger

  action_fallback(TdIeWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.ingest_version_definitions()
  end

  swagger_path :index do
    description("Ingest Versions")

    parameters do
      search(:body, Schema.ref(:IngestVersionFilterRequest), "Search query and filter parameters")
    end

    response(200, "OK", Schema.ref(:IngestVersionsResponse))
  end

  def index(conn, params) do
    user = conn.assigns[:current_user]

    params
    |> Search.search_ingest_versions(user)
    |> render_search_results(conn)
  end

  swagger_path :search do
    description("Ingest Versions")

    parameters do
      search(:body, Schema.ref(:IngestVersionFilterRequest), "Search query and filter parameters")
    end

    response(200, "OK", Schema.ref(:IngestVersionsResponse))
  end

  def search(conn, params) do
    user = conn.assigns[:current_user]
    page = params |> Map.get("page", 0)
    size = params |> Map.get("size", 50)

    params
    |> Map.drop(["page", "size"])
    |> Search.search_ingest_versions(user, page, size)
    |> render_search_results(conn)
  end

  defp render_search_results(%{results: ingest_versions, total: total}, conn) do
    hypermedia =
      collection_hypermedia(
        "ingest_version",
        conn,
        ingest_versions,
        IngestVersion
      )

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("list.json", ingest_versions: ingest_versions, hypermedia: hypermedia)
  end

  def csv(conn, params) do
    user = conn.assigns[:current_user]

    %{results: ingest_versions} = Search.search_ingest_versions(params, user, 0, 10_000)

    conn
    |> put_resp_content_type("text/csv", "utf-8")
    |> put_resp_header("content-disposition", "attachment; filename=\"ingests.zip\"")
    |> send_resp(200, Download.to_csv(ingest_versions))
  end

  swagger_path :create do
    description("Creates a Ingest version child of Data Domain")
    produces("application/json")

    parameters do
      ingest(:body, Schema.ref(:IngestVersionCreate), "Ingest create attrs")
    end

    response(201, "Created", Schema.ref(:IngestVersionResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"ingest_version" => ingest_params}) do
    user = conn.assigns[:current_user]

    # validate fields that if not present are throwing internal server errors in bc creation
    validate_required_ingest_fields(ingest_params)

    ingest_type = Map.get(ingest_params, "type")
    template = TemplateCache.get_by_name!(ingest_type)
    content_schema = Map.get(template, :content)
    ingest_name = Map.get(ingest_params, "name")
    domain_id = Map.get(ingest_params, "domain_id")

    resource_domain =
      Map.new()
      |> Map.put(:resource_id, domain_id)
      |> Map.put(:resource_type, "domain")

    ingest_attrs =
      %{}
      |> Map.put("domain_id", domain_id)
      |> Map.put("type", ingest_type)
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now())

    creation_attrs =
      ingest_params
      |> Map.put("ingest", ingest_attrs)
      |> Map.put("content_schema", content_schema)
      |> Map.update("content", %{}, & &1)
      |> Map.put("last_change_by", conn.assigns.current_user.id)
      |> Map.put("last_change_at", DateTime.utc_now())
      |> Map.put("status", "draft")
      |> Map.put("version", 1)

    with {:can, true} <- {:can, can?(user, create_ingest(resource_domain))},
         :ok <- Ingests.check_ingest_name_availability(ingest_type, ingest_name),
         {:ok, %IngestVersion{} = version} <- Workflow.create_ingest(creation_attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.ingest_path(conn, :show, version.ingest))
      |> render("show.json", ingest_version: version, template: template)
    else
      error ->
        IngestSupport.handle_ingest_errors(conn, error)
    end
  rescue
    validation_error in ValidationError ->
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{errors: %{"#{validation_error.field}": [validation_error.error]}})
  end

  defp validate_required_ingest_fields(attrs) do
    if not Map.has_key?(attrs, "content") do
      raise ValidationError, field: "content", error: "blank"
    end

    if not Map.has_key?(attrs, "type") do
      raise ValidationError, field: "type", error: "blank"
    end
  end

  swagger_path :versions do
    description("List Ingest Versions")

    parameters do
      ingest_version_id(:path, :integer, "Ingest Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestVersionsResponse))
  end

  def versions(conn, %{"ingest_version_id" => ingest_version_id}) do
    user = conn.assigns[:current_user]

    ingest_version = Ingests.get_ingest_version!(ingest_version_id)

    case Search.list_ingest_versions(ingest_version.ingest_id, user) do
      %{results: ingest_versions} ->
        render(conn, "versions.json",
          ingest_versions: ingest_versions,
          hypermedia: hypermedia("ingest_version", conn, ingest_versions)
        )

      _ ->
        conn |> put_status(:unprocessable_entity) |> put_view(ErrorView) |> render("422.json")
    end
  end

  swagger_path :show do
    description("Show Ingest Version")
    produces("application/json")

    parameters do
      id(:path, :integer, "Ingest ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestVersionResponse))
    response(400, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns[:current_user]
    ingest_version = Ingests.get_ingest_version!(id)

    with {:can, true} <- {:can, can?(user, view_ingest(ingest_version))} do
      template = get_template(ingest_version)
      ingest_version = Ingests.with_domain(ingest_version)
      links = Links.get_links(ingest_version)

      render(conn, "show.json",
        ingest_version: ingest_version,
        links: links,
        links_hypermedia: links_hypermedia(conn, links, ingest_version),
        hypermedia: hypermedia("ingest_version", conn, ingest_version),
        template: template
      )
    end
  end

  defp links_hypermedia(conn, links, ingest_version) do
    collection_hypermedia(
      "ingest_version_ingest_link",
      conn,
      Enum.map(links, &annotate(&1, ingest_version)),
      Link
    )
  end

  defp annotate(link, %IngestVersion{
         id: ingest_version_id,
         ingest: %{domain_id: domain_id}
       }) do
    link
    |> Map.put(:ingest_version_id, ingest_version_id)
    |> Map.put(:domain_id, domain_id)
    |> Map.put(:hint, :link)
  end

  swagger_path :delete do
    description("Delete a Ingest version")
    produces("application/json")

    parameters do
      id(:path, :integer, "Ingest Version ID", required: true)
    end

    response(204, "No Content")
    response(400, "Client Error")
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns[:current_user]

    with ingest_version <- Ingests.get_ingest_version!(id),
         {:can, true} <- {:can, can?(user, delete(ingest_version))},
         {:ok, %IngestVersion{}} <- Ingests.delete_ingest_version(ingest_version, user) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :send_for_approval do
    description("Submit a draft Ingest for approval")
    produces("application/json")

    parameters do
      id(:path, :integer, "Ingest Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Ingest invalid state")
  end

  def send_for_approval(conn, %{"ingest_version_id" => id}) do
    user = conn.assigns[:current_user]

    with ingest_version <- Ingests.get_ingest_version!(id),
         {:status, "draft", true} <- {:status, ingest_version.status, ingest_version.current},
         {:can, true} <- {:can, can?(user, send_for_approval(ingest_version))},
         {:ok, %{updated: updated}} <- Workflow.submit_ingest_version(ingest_version, user) do
      render(
        conn,
        "show.json",
        ingest_version: Ingests.with_domain(updated),
        hypermedia: hypermedia("ingest_version", conn, updated),
        template: get_template(updated)
      )
    else
      {:status, _, _} -> {:error, :unprocessable_entity}
    end
  end

  swagger_path :publish do
    description("Publish a Ingest which is pending approval")
    produces("application/json")

    parameters do
      id(:path, :integer, "Ingest Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Ingest invalid state")
  end

  def publish(conn, %{"ingest_version_id" => id}) do
    user = conn.assigns[:current_user]

    with ingest_version <- Ingests.get_ingest_version!(id),
         {:status, {"pending_approval", true}} <-
           {:status, {ingest_version.status, ingest_version.current}},
         {:can, true} <- {:can, can?(user, publish(ingest_version))},
         {:ok, %{published: %IngestVersion{} = ingest}} <-
           Workflow.publish_ingest_version(ingest_version, user) do
      render(
        conn,
        "show.json",
        ingest_version: Ingests.with_domain(ingest),
        hypermedia: hypermedia("ingest_version", conn, ingest),
        template: get_template(ingest_version)
      )
    else
      {:status, _} -> {:error, :unprocessable_entity}
    end
  end

  swagger_path :reject do
    description("Reject a Ingest which is pending approval")
    produces("application/json")

    parameters do
      id(:path, :integer, "Ingest Version ID", required: true)
      reject_reason(:body, :string, "Rejection reason")
    end

    response(200, "OK", Schema.ref(:IngestResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Ingest invalid state")
  end

  def reject(conn, %{"ingest_version_id" => id} = params) do
    user = conn.assigns[:current_user]
    reason = Map.get(params, "reject_reason")

    with ingest_version <- Ingests.get_ingest_version!(id),
         {:status, "pending_approval", true} <-
           {:status, ingest_version.status, ingest_version.current},
         {:can, true} <- {:can, can?(user, reject(ingest_version))},
         {:ok, %{rejected: version}} <-
           Workflow.reject_ingest_version(ingest_version, reason, user) do
      render(
        conn,
        "show.json",
        ingest_version: Ingests.with_domain(version),
        hypermedia: hypermedia("ingest_version", conn, version),
        template: get_template(ingest_version)
      )
    else
      {:status, _, _} -> {:error, :unprocessable_entity}
    end
  end

  swagger_path :undo_rejection do
    description("Create a draft from a rejected Ingest")
    produces("application/json")

    parameters do
      id(:path, :integer, "Ingest Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Ingest invalid state")
  end

  def undo_rejection(conn, %{"ingest_version_id" => id}) do
    user = conn.assigns[:current_user]

    with ingest_version <- Ingests.get_ingest_version!(id),
         {:status, "rejected", true} <- {:status, ingest_version.status, ingest_version.current},
         {:can, true} <- {:can, can?(user, undo_rejection(ingest_version))},
         {:ok, %{updated: updated}} <- Workflow.undo_rejected_ingest_version(ingest_version, user) do
      render(
        conn,
        "show.json",
        ingest_version: Ingests.with_domain(updated),
        hypermedia: hypermedia("ingest_version", conn, updated),
        template: get_template(updated)
      )
    else
      {:status, _, _} -> {:error, :unprocessable_entity}
    end
  end

  swagger_path :version do
    description("Create a new draft from a published Ingest")
    produces("application/json")

    parameters do
      id(:path, :integer, "Ingest Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Ingest invalid state")
  end

  def version(conn, %{"ingest_version_id" => id}) do
    user = conn.assigns[:current_user]

    with ingest_version <- Ingests.get_ingest_version!(id),
         {:status, "published", true} <- {:status, ingest_version.status, ingest_version.current},
         {:can, true} <- {:can, can?(user, version(ingest_version))},
         {:ok, %{current: %IngestVersion{} = new_version}} <-
           Workflow.new_ingest_version(ingest_version, user) do
      conn
      |> put_status(:created)
      |> render(
        "show.json",
        ingest_version: new_version,
        hypermedia: hypermedia("ingest_version", conn, new_version),
        template: get_template(new_version)
      )
    else
      {:status, _, _} -> {:error, :unprocessable_entity}
    end
  end

  swagger_path :deprecate do
    description("Deprecate a published Ingest")
    produces("application/json")

    parameters do
      id(:path, :integer, "Ingest Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Ingest invalid state")
  end

  def deprecate(conn, %{"ingest_version_id" => id}) do
    user = conn.assigns[:current_user]

    with ingest_version <- Ingests.get_ingest_version!(id),
         {:status, "published", true} <- {:status, ingest_version.status, ingest_version.current},
         {:can, true} <- {:can, can?(user, deprecate(ingest_version))},
         {:ok, %{updated: updated}} <- Workflow.deprecate_ingest_version(ingest_version, user) do
      render(
        conn,
        "show.json",
        ingest_version: Ingests.with_domain(updated),
        hypermedia: hypermedia("ingest_version", conn, updated),
        template: get_template(updated)
      )
    else
      {:status, _, _} -> {:error, :unprocessable_entity}
    end
  end

  swagger_path :update do
    description("Updates Ingest Version")
    produces("application/json")

    parameters do
      ingest_version(:body, Schema.ref(:IngestVersionUpdate), "Ingest Version update attrs")
      id(:path, :integer, "Ingest Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestVersionResponse))
    response(400, "Client Error")
  end

  def update(conn, %{"id" => id, "ingest_version" => ingest_version_params}) do
    user = conn.assigns[:current_user]

    ingest_version = Ingests.get_ingest_version!(id)
    ingest_name = Map.get(ingest_version_params, "name")
    template = get_template(ingest_version)
    content_schema = Map.get(template, :content)

    ingest_attrs =
      %{}
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now())

    update_params =
      ingest_version_params
      |> Map.put("ingest", ingest_attrs)
      |> Map.put("content_schema", content_schema)
      |> Map.update("content", %{}, & &1)
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now())

    with {:can, true} <- {:can, can?(user, update(ingest_version))},
         :ok <-
           Ingests.check_ingest_name_availability(
             template.name,
             ingest_name,
             ingest_version.ingest.id
           ),
         {:ok, %IngestVersion{} = ingest_version} <-
           Workflow.update_ingest_version(ingest_version, update_params) do
      render(
        conn,
        "show.json",
        ingest_version: ingest_version,
        hypermedia: hypermedia("ingest_version", conn, ingest_version),
        template: template
      )
    else
      false ->
        conn |> put_status(:forbidden) |> put_view(ErrorView) |> render("403.json")

      {:error, :name_not_available} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{name: ["bc_version unique"]}})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(TdIeWeb.ChangesetView)
        |> render("error.json", changeset: changeset)

      _error ->
        conn |> put_status(:unprocessable_entity) |> put_view(ErrorView) |> render("422.json")
    end
  end

  def get_template(%IngestVersion{} = version) do
    version
    |> Map.get(:ingest)
    |> Map.get(:type)
    |> TemplateCache.get_by_name!()
  end
end
