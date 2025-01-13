defmodule TdIeWeb.IngestVersionController do
  @moduledoc """
  Controller of Ingest version requests
  """

  use TdHypermedia, :controller
  use TdIeWeb, :controller
  import Canada, only: [can?: 2]

  alias TdCache.TemplateCache
  alias TdIe.Ingests
  alias TdIe.Ingests.Download
  alias TdIe.Ingests.IngestVersion
  alias TdIe.Ingests.Links
  alias TdIe.Ingests.Search
  alias TdIe.Ingests.Workflow
  alias TdIeWeb.ErrorView
  alias TdIeWeb.IngestSupport

  require Logger

  action_fallback(TdIeWeb.FallbackController)

  def index(conn, params) do
    claims = conn.assigns[:current_resource]

    params
    |> Search.search_ingest_versions(claims)
    |> render_search_results(conn)
  end

  def search(conn, params) do
    claims = conn.assigns[:current_resource]
    page = params |> Map.get("page", 0)
    size = params |> Map.get("size", 50)

    params
    |> Map.drop(["page", "size"])
    |> Search.search_ingest_versions(claims, page, size)
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
    claims = conn.assigns[:current_resource]

    %{results: ingest_versions} = Search.search_ingest_versions(params, claims, 0, 10_000)

    conn
    |> put_resp_content_type("text/csv", "utf-8")
    |> put_resp_header("content-disposition", "attachment; filename=\"ingests.zip\"")
    |> send_resp(200, Download.to_csv(ingest_versions))
  end

  def create(conn, %{"ingest_version" => ingest_params}) do
    %{user_id: user_id} = claims = conn.assigns[:current_resource]

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
      |> Map.put("last_change_by", user_id)
      |> Map.put("last_change_at", DateTime.utc_now())

    creation_attrs =
      ingest_params
      |> Map.put("ingest", ingest_attrs)
      |> Map.put("content_schema", content_schema)
      |> Map.put_new("content", %{})
      |> Map.put("last_change_by", user_id)
      |> Map.put("last_change_at", DateTime.utc_now())
      |> Map.put("status", "draft")
      |> Map.put("version", 1)

    with {:can, true} <- {:can, can?(claims, create_ingest(resource_domain))},
         :ok <- Ingests.check_ingest_name_availability(ingest_type, ingest_name),
         {:ok, %{ingest_version: version}} <- Workflow.create_ingest(creation_attrs) do
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

  def versions(conn, %{"ingest_version_id" => ingest_version_id}) do
    claims = conn.assigns[:current_resource]

    ingest_version = Ingests.get_ingest_version!(ingest_version_id)

    %{results: ingest_versions} = Search.list_ingest_versions(ingest_version.ingest_id, claims)

    render(conn, "versions.json",
      ingest_versions: ingest_versions,
      hypermedia: hypermedia("ingest_version", conn, ingest_versions)
    )
  end

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]
    ingest_version = Ingests.get_ingest_version!(id)

    with {:can, true} <- {:can, can?(claims, view_ingest(ingest_version))} do
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

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with ingest_version <- Ingests.get_ingest_version!(id),
         {:can, true} <- {:can, can?(claims, delete(ingest_version))},
         {:ok, %IngestVersion{}} <- Ingests.delete_ingest_version(ingest_version, claims) do
      send_resp(conn, :no_content, "")
    end
  end

  def send_for_approval(conn, %{"ingest_version_id" => id}) do
    claims = conn.assigns[:current_resource]

    with ingest_version <- Ingests.get_ingest_version!(id),
         {:status, "draft", true} <- {:status, ingest_version.status, ingest_version.current},
         {:can, true} <- {:can, can?(claims, send_for_approval(ingest_version))},
         {:ok, %{updated: updated}} <- Workflow.submit_ingest_version(ingest_version, claims) do
      render(
        conn,
        "show.json",
        ingest_version: Ingests.with_domain(updated),
        hypermedia: hypermedia("ingest_version", conn, updated),
        template: get_template(updated)
      )
    else
      {:status, _, _} -> {:error, :unprocessable_entity}
      error -> error
    end
  end

  def publish(conn, %{"ingest_version_id" => id}) do
    claims = conn.assigns[:current_resource]

    with ingest_version <- Ingests.get_ingest_version!(id),
         {:status, {"pending_approval", true}} <-
           {:status, {ingest_version.status, ingest_version.current}},
         {:can, true} <- {:can, can?(claims, publish(ingest_version))},
         {:ok, %{published: %IngestVersion{} = ingest}} <-
           Workflow.publish_ingest_version(ingest_version, claims) do
      render(
        conn,
        "show.json",
        ingest_version: Ingests.with_domain(ingest),
        hypermedia: hypermedia("ingest_version", conn, ingest),
        template: get_template(ingest_version)
      )
    else
      {:status, _} -> {:error, :unprocessable_entity}
      error -> error
    end
  end

  def reject(conn, %{"ingest_version_id" => id} = params) do
    claims = conn.assigns[:current_resource]
    reason = Map.get(params, "reject_reason")

    with ingest_version <- Ingests.get_ingest_version!(id),
         {:status, "pending_approval", true} <-
           {:status, ingest_version.status, ingest_version.current},
         {:can, true} <- {:can, can?(claims, reject(ingest_version))},
         {:ok, %{rejected: version}} <-
           Workflow.reject_ingest_version(ingest_version, reason, claims) do
      render(
        conn,
        "show.json",
        ingest_version: Ingests.with_domain(version),
        hypermedia: hypermedia("ingest_version", conn, version),
        template: get_template(ingest_version)
      )
    else
      {:status, _, _} -> {:error, :unprocessable_entity}
      error -> error
    end
  end

  def undo_rejection(conn, %{"ingest_version_id" => id}) do
    claims = conn.assigns[:current_resource]

    with ingest_version <- Ingests.get_ingest_version!(id),
         {:status, "rejected", true} <- {:status, ingest_version.status, ingest_version.current},
         {:can, true} <- {:can, can?(claims, undo_rejection(ingest_version))},
         {:ok, %{updated: updated}} <-
           Workflow.undo_rejected_ingest_version(ingest_version, claims) do
      render(
        conn,
        "show.json",
        ingest_version: Ingests.with_domain(updated),
        hypermedia: hypermedia("ingest_version", conn, updated),
        template: get_template(updated)
      )
    else
      {:status, _, _} -> {:error, :unprocessable_entity}
      error -> error
    end
  end

  def version(conn, %{"ingest_version_id" => id}) do
    claims = conn.assigns[:current_resource]

    with ingest_version <- Ingests.get_ingest_version!(id),
         {:status, "published", true} <- {:status, ingest_version.status, ingest_version.current},
         {:can, true} <- {:can, can?(claims, version(ingest_version))},
         {:ok, %{current: %IngestVersion{} = new_version}} <-
           Workflow.new_ingest_version(ingest_version, claims) do
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
      error -> error
    end
  end

  def deprecate(conn, %{"ingest_version_id" => id}) do
    claims = conn.assigns[:current_resource]

    with ingest_version <- Ingests.get_ingest_version!(id),
         {:status, "published", true} <- {:status, ingest_version.status, ingest_version.current},
         {:can, true} <- {:can, can?(claims, deprecate(ingest_version))},
         {:ok, %{updated: updated}} <- Workflow.deprecate_ingest_version(ingest_version, claims) do
      render(
        conn,
        "show.json",
        ingest_version: Ingests.with_domain(updated),
        hypermedia: hypermedia("ingest_version", conn, updated),
        template: get_template(updated)
      )
    else
      {:status, _, _} -> {:error, :unprocessable_entity}
      error -> error
    end
  end

  def update(conn, %{"id" => id, "ingest_version" => ingest_version_params}) do
    %{user_id: user_id} = claims = conn.assigns[:current_resource]

    ingest_version = Ingests.get_ingest_version!(id)
    ingest_name = Map.get(ingest_version_params, "name")
    template = get_template(ingest_version)
    content_schema = Map.get(template, :content)

    ingest_attrs =
      %{}
      |> Map.put("last_change_by", user_id)
      |> Map.put("last_change_at", DateTime.utc_now())

    update_params =
      ingest_version_params
      |> Map.put("ingest", ingest_attrs)
      |> Map.put("content_schema", content_schema)
      |> Map.update("content", %{}, & &1)
      |> Map.put("last_change_by", user_id)
      |> Map.put("last_change_at", DateTime.utc_now())

    with {:can, true} <- {:can, can?(claims, update(ingest_version))},
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
