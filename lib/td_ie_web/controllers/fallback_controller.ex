defmodule TdIeWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use TdIeWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(TdIeWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, _field, %Ecto.Changeset{} = changeset, _changes_so_far}) do
    call(conn, {:error, changeset})
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(TdIeWeb.ErrorView)
    |> render("404.json")
  end

  def call(conn, {:error, :unprocessable_entity}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(TdIeWeb.ErrorView)
    |> render("422.json")
  end

  def call(conn, {:can, false}) do
    conn
    |> put_status(:forbidden)
    |> put_view(TdBgWeb.ErrorView)
    |> render("403.json")
  end
end
