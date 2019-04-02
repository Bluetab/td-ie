defmodule TdIeWeb.IngestExecutionController do
  use TdIeWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdIe.Ingests
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestExecution
  alias TdIeWeb.IngestSupport
  alias TdIeWeb.SwaggerDefinitions

  action_fallback(TdIeWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.ingest_execution_definitions()
  end

  swagger_path :index do
    description("List Ingest Executions")

    parameters do
      ingest_id(:path, :integer, "ingest ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestExecutionsResponse))
  end

  def index(conn, %{"ingest_id" => ingest_id}) do
    ingest_executions = Ingests.list_ingest_executions(ingest_id)
    render(conn, "index.json", ingest_executions: ingest_executions)
  end

  swagger_path :create do
    description("Creates a Ingest Execution")
    produces("application/json")

    parameters do
      ingest_id(:path, :integer, "ingest ID", required: true)

      ingest_execution(
        :body,
        Schema.ref(:IngestExecutionUpdate),
        "Ingest execution create attrs"
      )
    end

    response(201, "Created", Schema.ref(:IngestExecutionResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"ingest_id" => ingest_id, "ingest_execution" => ingest_execution_params}) do
    user = conn.assigns[:current_user]
    params = Map.put(ingest_execution_params, "ingest_id", ingest_id)

    with %Ingest{domain_id: domain_id} <- Ingests.get_ingest!(ingest_id),
         true <- can?(user, create_ingest(%{resource_type: "domain", resource_id: domain_id})),
         {:ok, %IngestExecution{} = ingest_execution} <- Ingests.create_ingest_execution(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        ingest_ingest_execution_path(conn, :show, ingest_id, ingest_execution)
      )
      |> render("show.json", ingest_execution: ingest_execution)
    else
      error ->
        IngestSupport.handle_ingest_errors(conn, error)
    end
  end

  swagger_path :show do
    description("Show ingest executions")
    produces("application/json")

    parameters do
      ingest_id(:path, :integer, "ingest ID", required: true)
      id(:path, :integer, "ingest execution ID", required: true)
    end

    response(200, "OK", Schema.ref(:IngestExecutionResponse))
    response(400, "Client Error")
  end

  def show(conn, %{"ingest_id" => _ingest_id, "id" => id}) do
    ingest_execution = Ingests.get_ingest_execution!(id)
    render(conn, "show.json", ingest_execution: ingest_execution)
  end

  swagger_path :update do
    description("Updates ingests executions")
    produces("application/json")

    parameters do
      ingest_id(:path, :integer, "ingest ID", required: true)
      id(:path, :integer, "ingest executions ID", required: true)

      ingest_execution(
        :body,
        Schema.ref(:IngestExecutionUpdate),
        "ingest executions update attrs"
      )
    end

    response(200, "OK", Schema.ref(:IngestExecutionResponse))
    response(400, "Client Error")
  end

  def update(conn, %{
        "ingest_id" => ingest_id,
        "id" => id,
        "ingest_execution" => ingest_execution_params
      }) do
    params = Map.put(ingest_execution_params, "ingest_id", ingest_id)
    ingest_execution = Ingests.get_ingest_execution!(id)

    with {:ok, %IngestExecution{} = ingest_execution} <-
           Ingests.update_ingest_execution(ingest_execution, params) do
      render(conn, "show.json", ingest_execution: ingest_execution)
    end
  end

  swagger_path :delete do
    description("Delete a Ingest Execution")
    produces("application/json")

    parameters do
      id(:path, :integer, "Ingest Execution ID", required: true)
    end

    response(204, "No Content")
    response(400, "Client Error")
  end

  def delete(conn, %{"id" => id}) do
    ingest_execution = Ingests.get_ingest_execution!(id)

    with {:ok, %IngestExecution{}} <- Ingests.delete_ingest_execution(ingest_execution) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :add_execution_by_name do
    description("Creates a Ingest Execution By Name")
    produces("application/json")

    parameters do
      ingest_by_name(:body, Schema.ref(:IngestExecutionByName), "Ingest Execution By Name",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:IngestExecutionResponse))
    response(401, "User is not authorized to perform this action")
    response(400, "Client Error")
  end

  def add_execution_by_name(conn, %{
        "ingest_name" => ingest_name,
        "ingest_execution" => ingest_execution_params
      }) do
    user = conn.assigns[:current_user]

    with [%{id: ingest_id}] <- Ingests.get_ingest_by_name(ingest_name) do
      ingest = Ingests.get_ingest!(ingest_id)
      params = Map.put(ingest_execution_params, "ingest_id", ingest_id)

      with %Ingest{domain_id: domain_id} <- ingest,
           true <- can?(user, create_ingest(%{resource_type: "domain", resource_id: domain_id})),
           {:ok, %IngestExecution{} = ingest_execution} <- Ingests.create_ingest_execution(params) do
        conn
        |> put_status(:created)
        |> put_resp_header(
          "location",
          ingest_ingest_execution_path(conn, :show, ingest_id, ingest_execution)
        )
        |> render("show.json", ingest_execution: ingest_execution)
      else
        error ->
          IngestSupport.handle_ingest_errors(conn, error)
      end
    else
      [] ->
        IngestSupport.handle_ingest_errors(conn, {:ingest_not_found})

      error ->
        IngestSupport.handle_ingest_errors(conn, error)
    end
  end
end
