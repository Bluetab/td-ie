defmodule TdIeWeb.IngestExecutionControllerTest do
  @moduledoc """
  Controller test of ingest execution entities
  """
  use TdIeWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  @create_attrs %{
    end_timestamp: ~N[2010-04-17 14:00:00.000000],
    start_timestamp: ~N[2010-04-17 14:00:00.000000],
    status: "some status",
    file_name: "some file_name",
    file_size: 42,
    description: "some description",
    records: 10
  }
  @update_attrs %{
    end_timestamp: ~N[2011-05-18 15:01:01.000000],
    start_timestamp: ~N[2011-05-18 15:01:01.000000],
    status: "some updated status",
    file_name: "some updated file_name",
    file_size: 53,
    description: "some updated description",
    records: 11
  }
  @invalid_attrs %{end_timestamp: nil, start_timestamp: nil, status: nil, ingest_id: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all ingest_executions", %{conn: conn, swagger_schema: schema} do
      %{id: ingest_id} = insert(:ingest)
      conn = get(conn, Routes.ingest_ingest_execution_path(conn, :index, ingest_id))
      validate_resp_schema(conn, schema, "IngestExecutionsResponse")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create ingest_execution" do
    @tag :admin_authenticated
    test "renders ingest_execution when data is valid", %{conn: conn, swagger_schema: schema} do
      %{ingest_id: ingest_id} = insert(:ingest_version)

      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.ingest_ingest_execution_path(conn, :create, ingest_id),
                 ingest_execution: @create_attrs
               )
               |> validate_resp_schema(schema, "IngestExecutionResponse")
               |> json_response(:created)

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_ingest_execution_path(conn, :show, ingest_id, id))
               |> validate_resp_schema(schema, "IngestExecutionResponse")
               |> json_response(:ok)

      assert data == %{
               "id" => id,
               "end_timestamp" => "2010-04-17T14:00:00",
               "start_timestamp" => "2010-04-17T14:00:00",
               "status" => "some status",
               "ingest_id" => ingest_id,
               "file_name" => "some file_name",
               "file_size" => 42,
               "description" => "some description",
               "records" => 10
             }
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      %{id: ingest_id} = insert(:ingest)

      assert %{"errors" => errors} =
               conn
               |> post(Routes.ingest_ingest_execution_path(conn, :create, ingest_id),
                 ingest_execution: @invalid_attrs
               )
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end
  end

  describe "create ingest_execution_by_name" do
    @tag :admin_authenticated
    test "renders ingest_execution_by_name when data is valid", %{
      conn: conn,
      swagger_schema: schema
    } do
      insert(:ingest_version, name: "nombre sobrescrito")

      assert %{"data" => _data} =
               conn
               |> post(Routes.ingest_execution_path(conn, :add_execution_by_name),
                 ingest_name: "nombre sobrescrito",
                 ingest_execution: @create_attrs
               )
               |> validate_resp_schema(schema, "IngestExecutionByNameResponse")
               |> json_response(:created)
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      insert(:ingest_version, name: "nombre sobrescrito")

      assert %{"errors" => errors} =
               conn
               |> post(Routes.ingest_execution_path(conn, :add_execution_by_name),
                 ingest_name: "nombre sobrescrito",
                 ingest_execution: @invalid_attrs
               )
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end

    @tag :admin_authenticated
    test "renders errors when data is valid, but name invalid", %{conn: conn} do
      insert(:ingest_version, name: "nombre sobrescrito")

      assert %{"error" => error} =
               conn
               |> post(Routes.ingest_execution_path(conn, :add_execution_by_name),
                 ingest_name: "name",
                 ingest_execution: @create_attrs
               )
               |> json_response(:not_found)

      assert error == "Ingest name not found"
    end
  end

  describe "update ingest_execution" do
    @tag :admin_authenticated
    test "renders ingest_execution when data is valid", %{conn: conn, swagger_schema: schema} do
      %{ingest_id: ingest_id} = insert(:ingest_version)
      %{id: id} = ingest_execution = insert(:ingest_execution, ingest_id: ingest_id)

      assert %{"data" => data} =
               conn
               |> put(
                 Routes.ingest_ingest_execution_path(conn, :update, ingest_id, ingest_execution),
                 ingest_execution: @update_attrs
               )
               |> validate_resp_schema(schema, "IngestExecutionResponse")
               |> json_response(:ok)

      assert %{"id" => ^id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_ingest_execution_path(conn, :show, ingest_id, id))
               |> validate_resp_schema(schema, "IngestExecutionResponse")
               |> json_response(:ok)

      assert data == %{
               "id" => id,
               "end_timestamp" => "2011-05-18T15:01:01",
               "start_timestamp" => "2011-05-18T15:01:01",
               "status" => "some updated status",
               "ingest_id" => ingest_id,
               "file_name" => "some updated file_name",
               "file_size" => 53,
               "description" => "some updated description",
               "records" => 11
             }
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      %{id: ingest_id} = ingest_execution = insert(:ingest_execution)

      assert %{"errors" => errors} =
               conn
               |> put(
                 Routes.ingest_ingest_execution_path(conn, :update, ingest_id, ingest_execution),
                 ingest_execution: @invalid_attrs
               )
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end
  end

  describe "delete ingest_execution" do
    @tag :admin_authenticated
    test "deletes chosen ingest_execution", %{conn: conn} do
      %{ingest_id: ingest_id} = insert(:ingest_version)
      ingest_execution = insert(:ingest_execution, ingest_id: ingest_id)

      assert conn
             |> delete(
               Routes.ingest_ingest_execution_path(conn, :delete, ingest_id, ingest_execution)
             )
             |> response(:no_content)

      assert_error_sent(:not_found, fn ->
        get(conn, Routes.ingest_ingest_execution_path(conn, :show, ingest_id, ingest_execution))
      end)
    end
  end
end
