defmodule TdIeWeb.IngestExecutionController do
  use TdIeWeb, :controller

  import Canada, only: [can?: 2]

  alias TdIe.Ingests
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestExecution
  alias TdIeWeb.IngestSupport

  action_fallback(TdIeWeb.FallbackController)

  def index(conn, %{"ingest_id" => ingest_id}) do
    ingest_executions = Ingests.list_ingest_executions(ingest_id)
    render(conn, "index.json", ingest_executions: ingest_executions)
  end

  def create(conn, %{"ingest_id" => ingest_id, "ingest_execution" => ingest_execution_params}) do
    claims = conn.assigns[:current_resource]
    params = Map.put(ingest_execution_params, "ingest_id", ingest_id)

    with %Ingest{domain_id: domain_id} <- Ingests.get_ingest!(ingest_id),
         {:can, true} <-
           {:can, can?(claims, create_ingest(%{resource_type: "domain", resource_id: domain_id}))},
         {:ok, %IngestExecution{} = ingest_execution} <- Ingests.create_ingest_execution(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.ingest_ingest_execution_path(conn, :show, ingest_id, ingest_execution)
      )
      |> render("show.json", ingest_execution: ingest_execution)
    else
      error ->
        IngestSupport.handle_ingest_errors(conn, error)
    end
  end

  def show(conn, %{"ingest_id" => _ingest_id, "id" => id}) do
    ingest_execution = Ingests.get_ingest_execution!(id)
    render(conn, "show.json", ingest_execution: ingest_execution)
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

  def delete(conn, %{"id" => id}) do
    ingest_execution = Ingests.get_ingest_execution!(id)

    with {:ok, %IngestExecution{}} <- Ingests.delete_ingest_execution(ingest_execution) do
      send_resp(conn, :no_content, "")
    end
  end

  def add_execution_by_name(conn, %{
        "ingest_name" => ingest_name,
        "ingest_execution" => ingest_execution_params
      }) do
    claims = conn.assigns[:current_resource]

    case Ingests.get_ingest_by_name(ingest_name) do
      [%{id: ingest_id}] ->
        ingest = Ingests.get_ingest!(ingest_id)
        params = Map.put(ingest_execution_params, "ingest_id", ingest_id)

        with %Ingest{domain_id: domain_id} <- ingest,
             {:can, true} <-
               {:can,
                can?(claims, create_ingest(%{resource_type: "domain", resource_id: domain_id}))},
             {:ok, %IngestExecution{} = ingest_execution} <-
               Ingests.create_ingest_execution(params) do
          conn
          |> put_status(:created)
          |> put_resp_header(
            "location",
            Routes.ingest_ingest_execution_path(conn, :show, ingest_id, ingest_execution)
          )
          |> render("show.json", ingest_execution: ingest_execution)
        else
          error -> IngestSupport.handle_ingest_errors(conn, error)
        end

      [] ->
        IngestSupport.handle_ingest_errors(conn, {:ingest_not_found})

      error ->
        IngestSupport.handle_ingest_errors(conn, error)
    end
  end
end
