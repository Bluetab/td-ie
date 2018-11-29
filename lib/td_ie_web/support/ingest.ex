defmodule TdIeWeb.IngestSupport do
  @moduledoc false
  require Logger
  use TdIeWeb, :controller
  alias TdIe.ErrorConstantsSupport
  alias TdIeWeb.ErrorView

  @errors ErrorConstantsSupport.ingest_support_errors

  def handle_ingest_errors(conn, error) do
    case error do
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")
      {:name_not_available} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [@errors.existing_ingest]})
      {:not_valid_related_to} ->
        # TODO: change this error to standard format
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{related_to: ["invalid"]}})
      {:error, %Ecto.Changeset{data: %{__struct__: _}} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(TdIeWeb.ChangesetView, "error.json", changeset: changeset,
                  prefix: "ingest.error")
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(TdIeWeb.ChangesetView, "error.json", changeset: changeset,
                  prefix: "ingest.content.error")
      error ->
        Logger.error("Ingest... #{inspect(error)}")
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json")
    end
  end
end
