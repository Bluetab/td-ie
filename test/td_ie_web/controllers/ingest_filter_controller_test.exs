defmodule TdIeWeb.IngestFilterControllerTest do
  @moduledoc """
  Testing of ingest filter controller
  """
  use TdIeWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdIe.Permissions.MockPermissionResolver
  alias TdIeWeb.ApiServices.MockTdAuthService

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @user_name "user"
  describe "index" do
    @tag :admin_authenticated
    test "lists all filters (admin user)", %{conn: conn} do
      conn = get(conn, Routes.ingest_filter_path(conn, :index))
      assert json_response(conn, 200)["data"] == %{}
    end

    @tag authenticated_user: @user_name
    test "lists all filters (non-admin user)", %{conn: conn} do
      conn = get(conn, Routes.ingest_filter_path(conn, :index))
      assert json_response(conn, 200)["data"] == %{}
    end
  end
end
