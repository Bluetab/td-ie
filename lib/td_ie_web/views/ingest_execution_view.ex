defmodule TdIeWeb.IngestExecutionView do
  use TdIeWeb, :view
  alias TdIeWeb.IngestExecutionView

  def render("index.json", %{ingest_executions: ingest_executions}) do
    %{data: render_many(ingest_executions, IngestExecutionView, "ingest_execution.json")}
  end

  def render("show.json", %{ingest_execution: ingest_execution}) do
    %{data: render_one(ingest_execution, IngestExecutionView, "ingest_execution.json")}
  end

  def render("ingest_execution.json", %{ingest_execution: ingest_execution}) do
    %{
      id: ingest_execution.id,
      ingest_id: ingest_execution.ingest_id,
      start_timestamp: ingest_execution.start_timestamp,
      end_timestamp: ingest_execution.end_timestamp,
      status: ingest_execution.status,
      file_name: ingest_execution.file_name,
      file_size: ingest_execution.file_size
    }
  end
end
