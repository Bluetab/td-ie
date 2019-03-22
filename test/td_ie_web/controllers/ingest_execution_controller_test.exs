defmodule TdIeWeb.IngestExecutionControllerTest do
  @moduledoc """
  Controller test of ingest execution entities
  """
  use TdIeWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import TdIeWeb.Authentication, only: :functions

  alias TdIe.Permissions.MockPermissionResolver
  alias TdIeWeb.ApiServices.MockTdAuthService

  @create_attrs %{
    end_timestamp: ~N[2010-04-17 14:00:00.000000],
    start_timestamp: ~N[2010-04-17 14:00:00.000000],
    status: "some status",
    file_name: "some file_name",
    file_size: 42
  }
  @update_attrs %{
    end_timestamp: ~N[2011-05-18 15:01:01.000000],
    start_timestamp: ~N[2011-05-18 15:01:01.000000],
    status: "some updated status",
    file_name: "some updated file_name",
    file_size: 53
  }
  @invalid_attrs %{end_timestamp: nil, start_timestamp: nil, status: nil, ingest_id: nil}

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all ingest_executions", %{conn: conn, swagger_schema: schema} do
      %{id: ingest_id} = insert(:ingest)
      conn = get conn, ingest_ingest_execution_path(conn, :index, ingest_id)
      validate_resp_schema(conn, schema, "IngestExecutionsResponse")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create ingest_execution" do
    @tag :admin_authenticated
    test "renders ingest_execution when data is valid", %{conn: conn, swagger_schema: schema} do
      %{id: ingest_id} = insert(:ingest)
      conn = post conn, ingest_ingest_execution_path(conn, :create, ingest_id), ingest_execution: @create_attrs
      validate_resp_schema(conn, schema, "IngestExecutionResponse")
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = recycle_and_put_headers(conn)
      conn = get conn, ingest_ingest_execution_path(conn, :show, ingest_id, id)
      validate_resp_schema(conn, schema, "IngestExecutionResponse")
      assert json_response(conn, 200)["data"] == %{
        "id" => id,
        "end_timestamp" => "2010-04-17T14:00:00.000000",
        "start_timestamp" => "2010-04-17T14:00:00.000000",
        "status" => "some status",
        "ingest_id" => ingest_id,
        "file_name" => "some file_name",
        "file_size" => 42
      }
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      %{id: ingest_id} = insert(:ingest)
      conn = post conn, ingest_ingest_execution_path(conn, :create, ingest_id), ingest_execution: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "create ingest_execution_by_name" do
    @tag :admin_authenticated
    test "renders ingest_execution_by_name when data is valid", %{conn: conn, swagger_schema: schema} do
      insert(:ingest)
      insert(:ingest_version, name: "nombre sobrescrito")
      conn = post conn, ingest_execution_path(conn, :add_execution_by_name),
        ingest_name: "nombre sobrescrito", ingest_execution: @create_attrs
      validate_resp_schema(conn, schema, "IngestExecutionByNameResponse")
      assert json_response(conn, 201)["data"]
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      insert(:ingest)
      insert(:ingest_version, name: "nombre sobrescrito")
      conn = post conn, ingest_execution_path(conn, :add_execution_by_name),
        ingest_name: "nombre sobrescrito", ingest_execution: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end

    @tag :admin_authenticated
    test "renders errors when data is valid, but name invalid", %{conn: conn} do
      insert(:ingest)
      insert(:ingest_version, name: "nombre sobrescrito")
      conn = post conn, ingest_execution_path(conn, :add_execution_by_name),
        ingest_name: "name", ingest_execution: @create_attrs
      assert json_response(conn, 404)["errors"] != %{}
    end

    @tag :admin_authenticated
    test "renders errors when everything is invalid", %{conn: conn} do
      insert(:ingest)
      insert(:ingest_version, name: "nombre sobrescrito")
      conn = post conn, ingest_execution_path(conn, :add_execution_by_name),
        ingest_name: "name", ingest_execution: @invalid_attrs
      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  describe "update ingest_execution" do

    @tag :admin_authenticated
    test "renders ingest_execution when data is valid", %{conn: conn, swagger_schema: schema} do
      %{id: ingest_id} = insert(:ingest)
      ingest_execution = insert(:ingest_execution, ingest_id: ingest_id)
      %{id: id} = ingest_execution
      conn = put conn, ingest_ingest_execution_path(conn, :update, ingest_id, ingest_execution),
        ingest_execution: @update_attrs
      validate_resp_schema(conn, schema, "IngestExecutionResponse")
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)
      conn = get conn, ingest_ingest_execution_path(conn, :show, ingest_id, id)
      validate_resp_schema(conn, schema, "IngestExecutionResponse")
      assert json_response(conn, 200)["data"] == %{
        "id" => id,
        "end_timestamp" => "2011-05-18T15:01:01.000000",
        "start_timestamp" => "2011-05-18T15:01:01.000000",
        "status" => "some updated status",
        "ingest_id" => ingest_id,
        "file_name" => "some updated file_name",
        "file_size" => 53
      }
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      %{id: ingest_id} = insert(:ingest)
      ingest_execution = insert(:ingest_execution, ingest_id: ingest_id)
      conn = put conn, ingest_ingest_execution_path(conn, :update, ingest_id, ingest_execution),
        ingest_execution: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete ingest_execution" do

    @tag :admin_authenticated
    test "deletes chosen ingest_execution", %{conn: conn} do
      %{id: ingest_id} = insert(:ingest)
      ingest_execution = insert(:ingest_execution, ingest_id: ingest_id)
      conn = delete conn, ingest_ingest_execution_path(conn, :delete, ingest_id, ingest_execution)
      assert response(conn, 204)
      assert_error_sent 404, fn ->
        conn = recycle_and_put_headers(conn)
        get conn, ingest_ingest_execution_path(conn, :show, ingest_id, ingest_execution)
      end
    end
  end
end
