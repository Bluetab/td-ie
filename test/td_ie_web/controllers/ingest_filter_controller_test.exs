defmodule TdIeWeb.IngestFilterControllerTest do
  @moduledoc """
  Testing of ingest filter controller
  """
  use TdIeWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all filters (admin user)", %{conn: conn} do
      conn = get(conn, Routes.ingest_filter_path(conn, :index))
      assert json_response(conn, 200)["data"] == %{}
    end

    @tag authenticated_user: "non_admin_user"
    test "lists all filters (non-admin user)", %{conn: conn} do
      conn = get(conn, Routes.ingest_filter_path(conn, :index))
      assert json_response(conn, 200)["data"] == %{}
    end
  end
end
