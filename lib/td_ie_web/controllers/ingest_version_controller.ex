defmodule TdIeWeb.IngestVersionController do
  @moduledoc """
  Controller of Ingest version requests
  """

  require Logger
  use TdIeWeb, :controller
  use TdIeWeb.Hypermedia, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdIe.Audit
  alias TdIe.Ingest.Download
  alias TdIe.Ingest.Search
  alias TdIe.Ingests
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestVersion
  alias TdIe.Repo
  alias TdIeWeb.ErrorView
  alias TdIeWeb.IngestSupport
  alias TdIeWeb.SwaggerDefinitions

  @df_cache Application.get_env(:td_ie, :df_cache)

  @events %{
    create_ingest_draft: "create_ingest_draft",
    update_ingest_draft: "update_ingest_draft",
    delete_ingest_draft: "delete_ingest_draft",
    new_ingest_draft: "new_ingest_draft",
    ingest_sent_for_approval: "ingest_sent_for_approval",
    ingest_rejected: "ingest_rejected",
    ingest_rejection_canceled: "ingest_rejection_canceled",
    ingest_published: "ingest_published",
    ingest_deprecated: "ingest_deprecated"
  }

  action_fallback(TdIeWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.ingest_version_definitions()
  end

  swagger_path :index do
    description("Ingest Versions")

    parameters do
      search(
        :body,
        Schema.ref(:IngestVersionFilterRequest),
        "Search query and filter parameters"
      )
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
      search(
        :body,
        Schema.ref(:IngestVersionFilterRequest),
        "Search query and filter parameters"
      )
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
    |> render(
      "list.json",
      ingest_versions: ingest_versions,
      hypermedia: hypermedia
    )
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
      ingest(
        :body,
        Schema.ref(:IngestVersionCreate),
        "Ingest create attrs"
      )
    end

    response(201, "Created", Schema.ref(:IngestVersionResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"ingest_version" => ingest_params}) do
    user = conn.assigns[:current_user]

    # validate fields that if not present are throwing internal server errors in bc creation
    validate_required_ingest_fields(ingest_params)

    ingest_type = Map.get(ingest_params, "type")
    template = @df_cache.get_template_by_name(ingest_type)
    content_schema = Map.get(template, :content)
    ingest_name = Map.get(ingest_params, "name")

    domain_id = Map.get(ingest_params, "domain_id")

    resource_domain =
      Map.new()
      |> Map.put(:resource_id, domain_id)
      |> Map.put(:resource_type, "domain")

    parent_id = Map.get(ingest_params, "parent_id", nil)

    ingest_attrs =
      %{}
      |> Map.put("domain_id", domain_id)
      |> Map.put("parent_id", parent_id)
      |> Map.put("type", ingest_type)
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now())

    creation_attrs =
      ingest_params
      |> Map.put("ingest", ingest_attrs)
      |> Map.put("content_schema", content_schema)
      |> Map.update("content", %{}, & &1)
      |> Map.update("related_to", [], & &1)
      |> Map.put("last_change_by", conn.assigns.current_user.id)
      |> Map.put("last_change_at", DateTime.utc_now())
      |> Map.put("status", Ingest.status().draft)
      |> Map.put("version", 1)

    related_to = Map.get(creation_attrs, "related_to")

    with true <- can?(user, create_ingest(resource_domain)),
         {:name_available} <- Ingests.check_ingest_name_availability(ingest_type, ingest_name),
         {:valid_related_to} <- check_valid_related_to(ingest_type, related_to),
         {:ok, %IngestVersion{} = version} <- Ingests.create_ingest(creation_attrs) do
      ingest_id = version.ingest.id

      audit = %{
        "audit" => %{
          "resource_id" => ingest_id,
          "resource_type" => "ingest",
          "payload" => creation_attrs
        }
      }

      Audit.create_event(conn, audit, @events.create_ingest_draft)

      conn =
        conn
        |> put_status(:created)
        |> put_resp_header(
          "location",
          ingest_path(conn, :show, version.ingest)
        )
        |> render(
          "show.json",
          ingest_version: version,
          template: template
        )

      conn
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

  defp check_valid_related_to(_type, []), do: {:valid_related_to}

  defp check_valid_related_to(type, ids) do
    input_count = length(ids)
    actual_count = Ingests.count_published_ingests(type, ids)
    if input_count == actual_count, do: {:valid_related_to}, else: {:not_valid_related_to}
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
        render(
          conn,
          "versions.json",
          ingest_versions: ingest_versions,
          hypermedia: hypermedia("ingest_version", conn, ingest_versions)
        )

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
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

    with true <- can?(user, view_ingest(ingest_version)) do
      template = get_template(ingest_version)

      ingest_version =
        ingest_version
        |> Repo.preload(ingest: [:children, :parent])
        |> Ingests.retrieve_parent(:domain)

      render(
        conn,
        "show.json",
        ingest_version: ingest_version,
        hypermedia: hypermedia("ingest_version", conn, ingest_version),
        template: template
      )
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
    end
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
    ingest_version = Ingests.get_ingest_version!(id)
    ingest_id = ingest_version.ingest.id

    with true <- can?(user, delete(ingest_version)),
         {:ok, %IngestVersion{}} <- Ingests.delete_ingest_version(ingest_version) do
      audit_payload =
        ingest_version
        |> Map.take([:version])

      audit = %{
        "audit" => %{
          "resource_id" => ingest_id,
          "resource_type" => "ingest",
          "payload" => audit_payload
        }
      }

      Audit.create_event(conn, audit, @events.delete_ingest_draft)

      send_resp(conn, :no_content, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
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
    ingest_version = Ingests.get_ingest_version!(id)
    draft = Ingest.status().draft

    case {ingest_version.status, ingest_version.current} do
      {^draft, true} ->
        send_for_approval(conn, user, ingest_version)

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
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
    ingest_version = Ingests.get_ingest_version!(id)
    pending_approval = Ingest.status().pending_approval

    case {ingest_version.status, ingest_version.current} do
      {^pending_approval, true} ->
        publish(conn, user, ingest_version)

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
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
    ingest_version = Ingests.get_ingest_version!(id)
    pending_approval = Ingest.status().pending_approval

    case {ingest_version.status, ingest_version.current} do
      {^pending_approval, true} ->
        reject(conn, user, ingest_version, Map.get(params, "reject_reason"))

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
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
    ingest_version = Ingests.get_ingest_version!(id)
    rejected = Ingest.status().rejected

    case {ingest_version.status, ingest_version.current} do
      {^rejected, true} ->
        undo_rejection(conn, user, ingest_version)

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
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
    ingest_version = Ingests.get_ingest_version!(id)
    published = Ingest.status().published

    case {ingest_version.status, ingest_version.current} do
      {^published, true} ->
        do_version(conn, user, ingest_version)

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
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
    ingest_version = Ingests.get_ingest_version!(id)
    published = Ingest.status().published

    case {ingest_version.status, ingest_version.current} do
      {^published, true} ->
        deprecate(conn, user, ingest_version)

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
    end
  end

  defp send_for_approval(conn, user, ingest_version) do
    update_status(
      conn,
      ingest_version,
      Ingest.status().pending_approval,
      @events.ingest_sent_for_approval,
      can?(user, send_for_approval(ingest_version))
    )
  end

  defp undo_rejection(conn, user, ingest_version) do
    update_status(
      conn,
      ingest_version,
      Ingest.status().draft,
      @events.ingest_rejection_canceled,
      can?(user, undo_rejection(ingest_version))
    )
  end

  defp publish(conn, user, ingest_version) do
    ingest_id = ingest_version.ingest.id

    with true <- can?(user, publish(ingest_version)),
         {:ok, %{published: %IngestVersion{} = ingest}} <-
           Ingests.publish_ingest_version(ingest_version) do
      audit = %{
        "audit" => %{
          "resource_id" => ingest_id,
          "resource_type" => "ingest",
          "payload" => %{}
        }
      }

      Audit.create_event(conn, audit, @events.ingest_published)

      render(
        conn,
        "show.json",
        ingest_version: ingest,
        hypermedia: hypermedia("ingest_version", conn, ingest),
        template: get_template(ingest_version)
      )
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
    end
  end

  defp reject(conn, user, ingest_version, reason) do
    attrs = %{reject_reason: reason}

    with true <- can?(user, reject(ingest_version)),
         {:ok, %IngestVersion{} = version} <- Ingests.reject_ingest_version(ingest_version, attrs) do
      ingest_id = version.ingest.id

      audit = %{
        "audit" => %{
          "resource_id" => ingest_id,
          "resource_type" => "ingest",
          "payload" => %{}
        }
      }

      Audit.create_event(conn, audit, @events.ingest_rejected)

      render(
        conn,
        "show.json",
        ingest_version: version,
        hypermedia: hypermedia("ingest_version", conn, version),
        template: get_template(ingest_version)
      )
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
    end
  end

  defp deprecate(conn, user, ingest_version) do
    update_status(
      conn,
      ingest_version,
      Ingest.status().deprecated,
      @events.ingest_deprecated,
      can?(user, deprecate(ingest_version))
    )
  end

  defp update_status(conn, ingest_version, status, event, authorized) do
    attrs = %{status: status}
    ingest_id = ingest_version.ingest.id

    with true <- authorized,
         {:ok, %IngestVersion{} = ingest} <-
           Ingests.update_ingest_version_status(
             ingest_version,
             attrs
           ) do
      audit = %{
        "audit" => %{
          "resource_id" => ingest_id,
          "resource_type" => "ingest",
          "payload" => %{}
        }
      }

      Audit.create_event(conn, audit, event)

      render(
        conn,
        "show.json",
        ingest_version: ingest,
        hypermedia: hypermedia("ingest_version", conn, ingest),
        template: get_template(ingest)
      )
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
    end
  end

  defp do_version(conn, user, ingest_version) do
    ingest_id = ingest_version.ingest.id

    with true <- can?(user, version(ingest_version)),
         {:ok, %{current: %IngestVersion{} = new_version}} <-
           Ingests.new_ingest_version(user, ingest_version) do
      audit_payload =
        new_version
        |> Map.take([:version])

      audit = %{
        "audit" => %{
          "resource_id" => ingest_id,
          "resource_type" => "ingest",
          "payload" => audit_payload
        }
      }

      Audit.create_event(conn, audit, @events.new_ingest_draft)

      conn
      |> put_status(:created)
      |> render(
        "show.json",
        ingest_version: new_version,
        hypermedia: hypermedia("ingest_version", conn, new_version),
        template: get_template(new_version)
      )
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
    end
  end

  swagger_path :update do
    description("Updates Ingest Version")
    produces("application/json")

    parameters do
      ingest_version(
        :body,
        Schema.ref(:IngestVersionUpdate),
        "Ingest Version update attrs"
      )

      id(:path, :integer, "Ingest Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestVersionResponse))
    response(400, "Client Error")
  end

  def update(conn, %{"id" => id, "ingest_version" => ingest_version_params}) do
    user = conn.assigns[:current_user]

    ingest_version = Ingests.get_ingest_version!(id)
    ingest_id = ingest_version.ingest.id
    ingest_name = Map.get(ingest_version_params, "name")
    template = get_template(ingest_version)
    content_schema = Map.get(template, :content)

    parent_id = Map.get(ingest_version_params, "parent_id", nil)

    ingest_attrs =
      %{}
      |> Map.put("parent_id", parent_id)
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now())

    update_params =
      ingest_version_params
      |> Map.put("ingest", ingest_attrs)
      |> Map.put("content_schema", content_schema)
      |> Map.update("content", %{}, & &1)
      |> Map.update("related_to", [], & &1)
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now())

    related_to = Map.get(update_params, "related_to")

    with true <- can?(user, update(ingest_version)),
         {:name_available} <-
           Ingests.check_ingest_name_availability(
             template.name,
             ingest_name,
             ingest_version.ingest.id
           ),
         {:valid_related_to} <- Ingests.check_valid_related_to(template.name, related_to),
         {:ok, %IngestVersion{} = ingest_version} <-
           Ingests.update_ingest_version(
             ingest_version,
             update_params
           ) do
      audit_payload = get_changed_params(ingest_version, ingest_version)

      audit = %{
        "audit" => %{
          "resource_id" => ingest_id,
          "resource_type" => "ingest",
          "payload" => audit_payload
        }
      }

      Audit.create_event(conn, audit, @events.update_ingest_draft)

      render(
        conn,
        "show.json",
        ingest_version: ingest_version,
        hypermedia: hypermedia("ingest_version", conn, ingest_version),
        template: template
      )
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      {:name_not_available} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{name: ["bc_version unique"]}})

      {:not_valid_related_to} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{related_to: ["bc_version invalid"]}})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(TdIeWeb.ChangesetView, "error.json", changeset: changeset)

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
    end
  end

  defp get_changed_params(
         %IngestVersion{} = old,
         %IngestVersion{} = new
       ) do
    fields_to_compare = [:name, :description]

    diffs =
      Enum.reduce(fields_to_compare, %{}, fn field, acc ->
        oldval = Map.get(old, field)
        newval = Map.get(new, field)

        case oldval == newval do
          true -> acc
          false -> Map.put(acc, field, newval)
        end
      end)

    oldcontent = Map.get(old, :content)
    newcontent = Map.get(new, :content)

    added_keys = Map.keys(newcontent) -- Map.keys(oldcontent)

    added =
      Enum.reduce(added_keys, %{}, fn key, acc ->
        Map.put(acc, key, Map.get(newcontent, key))
      end)

    removed_keys = Map.keys(oldcontent) -- Map.keys(newcontent)

    removed =
      Enum.reduce(removed_keys, %{}, fn key, acc ->
        Map.put(acc, key, Map.get(oldcontent, key))
      end)

    changed_keys = Map.keys(newcontent) -- removed_keys -- added_keys

    changed =
      Enum.reduce(changed_keys, %{}, fn key, acc ->
        oldval = Map.get(oldcontent, key)
        newval = Map.get(newcontent, key)

        case oldval == newval do
          true -> acc
          false -> Map.put(acc, key, newval)
        end
      end)

    changed_content =
      %{}
      |> Map.put(:added, added)
      |> Map.put(:removed, removed)
      |> Map.put(:changed, changed)

    diffs
    |> Map.put(:content, changed_content)
  end

  def get_template(%IngestVersion{} = version) do
    version
    |> Map.get(:ingest)
    |> Map.get(:type)
    |> @df_cache.get_template_by_name
  end
end
