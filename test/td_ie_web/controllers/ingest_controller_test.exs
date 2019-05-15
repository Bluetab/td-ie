defmodule TdIeWeb.IngestControllerTest do
  @moduledoc """
  Controller test of ingest entities
  """
  use TdIeWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import TdIeWeb.Authentication, only: :functions
  import TdIe.TaxonomyHelper, only: :functions

  alias TdIe.Ingests.Ingest
  alias TdIe.Permissions.MockPermissionResolver
  alias TdIeWeb.ApiServices.MockTdAuthService

  @df_cache Application.get_env(:td_ie, :df_cache)

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
    start_supervised(@df_cache)
    :ok
  end

  defp to_rich_text(plain) do
    %{"document" => plain}
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "update ingest" do
    setup [:create_template]

    @tag :admin_authenticated
    test "renders ingest when data is valid", %{conn: conn, swagger_schema: schema} do
      domain = domain_fixture()
      user = build(:user)
      ingest_version = insert(:ingest_version, last_change_by: user.id)
      ingest = ingest_version.ingest
      ingest_id = ingest.id

      update_attrs = %{
        content: %{},
        name: "The new name",
        description: to_rich_text("The new description"),
        in_progress: false
      }

      conn =
        put(
          conn,
          Routes.ingest_path(conn, :update, ingest),
          ingest: update_attrs
        )

      validate_resp_schema(conn, schema, "IngestResponse")
      assert %{"id" => ^ingest_id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)
      conn = get(conn, Routes.ingest_path(conn, :show, ingest_id))
      validate_resp_schema(conn, schema, "IngestResponse")

      updated_ingest = json_response(conn, 200)["data"]

      assert Map.get(domain, :id) == updated_ingest |> Map.get("domain") |> Map.get("id")
      assert Map.get(domain, :name) == updated_ingest |> Map.get("domain") |> Map.get("name")

      update_attrs
      |> Enum.each(&assert updated_ingest |> Map.get(Atom.to_string(elem(&1, 0))) == elem(&1, 1))
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn, swagger_schema: schema} do
      user = build(:user)
      ingest_version = insert(:ingest_version, last_change_by: user.id)
      ingest_id = ingest_version.ingest.id

      update_attrs = %{
        content: %{},
        name: nil,
        description: to_rich_text("The new description"),
        in_progress: false
      }

      conn =
        put(
          conn,
          Routes.ingest_path(conn, :update, ingest_id),
          ingest: update_attrs
        )

      validate_resp_schema(conn, schema, "IngestResponse")
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update ingest status" do
    setup [:create_template]

    @transitions [
      {Ingest.status().draft, Ingest.status().pending_approval},
      {Ingest.status().pending_approval, Ingest.status().published},
      {Ingest.status().pending_approval, Ingest.status().rejected},
      {Ingest.status().rejected, Ingest.status().draft},
      {Ingest.status().published, Ingest.status().deprecated}
    ]

    Enum.each(@transitions, fn transition ->
      status_from = elem(transition, 0)
      status_to = elem(transition, 1)

      # Why do I need to pass a value ???
      @tag admin_authenticated: "xyz", status_from: status_from, status_to: status_to
      test "update ingest status change from #{status_from} to #{status_to}", %{
        conn: conn,
        swagger_schema: schema,
        status_from: status_from,
        status_to: status_to
      } do
        user = build(:user)

        ingest_version = insert(:ingest_version, status: status_from, last_change_by: user.id)

        ingest = ingest_version.ingest
        ingest_id = ingest.id

        update_attrs = %{
          status: status_to
        }

        conn =
          patch(
            conn,
            Routes.ingest_ingest_path(conn, :update_status, ingest),
            ingest: update_attrs
          )

        validate_resp_schema(conn, schema, "IngestResponse")
        assert %{"id" => ^ingest_id} = json_response(conn, 200)["data"]

        conn = recycle_and_put_headers(conn)
        conn = get(conn, Routes.ingest_path(conn, :show, ingest_id))
        validate_resp_schema(conn, schema, "IngestResponse")

        assert json_response(conn, 200)["data"]["status"] == status_to
      end
    end)
  end

  defp create_template(_) do
    attrs = %{id: 0, label: "some type", name: "some_type", content: [], scope: "ie"}

    @df_cache.put_template(attrs)
    :ok
  end
end
