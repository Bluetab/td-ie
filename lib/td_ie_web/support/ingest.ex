defmodule TdIeWeb.IngestSupport do
  @moduledoc false
  use TdIeWeb, :controller

  alias TdIe.ErrorConstantsSupport
  alias TdIeWeb.ErrorView

  require Logger

  @errors ErrorConstantsSupport.ingest_support_errors()

  def handle_ingest_errors(conn, error) do
    error =
      case error do
        {:error, _field, changeset, _changes_so_far} -> {:error, changeset}
        _ -> error
      end

    case error do
      {:can, false} ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      {:ingest_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Ingest name not found"})

      {:error, :name_not_available} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [@errors.existing_ingest]})

      {:error, %Ecto.Changeset{data: %{__struct__: _}} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(TdIeWeb.ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "ingest.error"
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(TdIeWeb.ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "ingest.content.error"
        )

      error ->
        Logger.error("Ingest... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end
end
