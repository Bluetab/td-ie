defmodule TdIeWeb.IngestControllerTest do
  @moduledoc """
  Controller test of ingest entities
  """
  use TdIeWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.TaxonomyCache
  alias TdIe.Permissions.MockPermissionResolver
  alias TdIeWeb.ApiServices.MockTdAuthService

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
    %{id: domain_id} = domain = build(:domain)
    on_exit(fn -> TaxonomyCache.delete_domain(domain_id) end)
    TaxonomyCache.put_domain(domain)
    [domain: domain]
  end

  defp to_rich_text(plain) do
    %{"document" => plain}
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "GET /api/ingests/search" do
    @tag :admin_authenticated
    test "find ingests by id and status", %{conn: conn, domain: %{id: domain_id}} do
      ids =
        [{"one", "draft"}, {"two", "published"}, {"three", "published"}]
        |> Enum.map(fn {name, status} ->
          insert(:ingest_version, name: name, status: status, domain_id: domain_id)
        end)
        |> Enum.map(& &1.ingest_id)
        |> Enum.join(",")

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_path(conn, :search), id: ids, status: "published")
               |> json_response(:ok)

      assert length(data) == 2
    end
  end

  describe "update ingest" do
    setup [:create_template]

    @tag :admin_authenticated
    test "renders ingest when data is valid", %{
      conn: conn,
      domain: domain,
      swagger_schema: schema
    } do
      %{id: domain_id, name: domain_name} = domain
      user = build(:user)
      ingest = insert(:ingest, domain_id: domain_id)
      ingest_id = ingest.id
      insert(:ingest_version, ingest: ingest, last_change_by: user.id)

      update_attrs = %{
        "content" => %{},
        "name" => "The new name",
        "description" => to_rich_text("The new description"),
        "in_progress" => false
      }

      assert %{"data" => data} =
               conn
               |> put(Routes.ingest_path(conn, :update, ingest), ingest: update_attrs)
               |> validate_resp_schema(schema, "IngestResponse")
               |> json_response(:ok)

      assert %{"id" => ^ingest_id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_path(conn, :show, ingest_id))
               |> validate_resp_schema(schema, "IngestResponse")
               |> json_response(:ok)

      assert data["domain"]["id"] == domain_id
      assert data["domain"]["name"] == domain_name

      Enum.each(update_attrs, &assert(Map.get(data, elem(&1, 0)) == elem(&1, 1)))
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn, swagger_schema: schema} do
      user = build(:user)
      ingest_version = insert(:ingest_version, last_change_by: user.id)
      ingest_id = ingest_version.ingest.id

      update_attrs = %{
        "content" => %{},
        "name" => nil,
        "description" => to_rich_text("The new description"),
        "in_progress" => false
      }

      assert %{"errors" => errors} =
               conn
               |> put(Routes.ingest_path(conn, :update, ingest_id), ingest: update_attrs)
               |> validate_resp_schema(schema, "IngestResponse")
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end
  end

  describe "update ingest status" do
    setup [:create_template]

    @transitions [
      {"draft", "pending_approval"},
      {"pending_approval", "published"},
      {"pending_approval", "rejected"},
      {"rejected", "draft"},
      {"published", "deprecated"}
    ]

    Enum.each(@transitions, fn transition ->
      status_from = elem(transition, 0)
      status_to = elem(transition, 1)

      @tag :admin_authenticated
      @tag status_from: status_from, status_to: status_to
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

        update_attrs = %{status: status_to}

        assert %{"data" => data} =
                 conn
                 |> patch(Routes.ingest_ingest_path(conn, :update_status, ingest),
                   ingest: update_attrs
                 )
                 |> validate_resp_schema(schema, "IngestResponse")
                 |> json_response(:ok)

        assert %{"id" => ^ingest_id} = data

        assert %{"data" => data} =
                 conn
                 |> get(Routes.ingest_path(conn, :show, ingest_id))
                 |> validate_resp_schema(schema, "IngestResponse")
                 |> json_response(:ok)

        assert %{"status" => ^status_to} = data
      end
    end)
  end

  defp create_template(_) do
    attrs = %{id: 0, label: "some type", name: "some_type", content: [], scope: "ie"}

    Templates.create_template(attrs)
    :ok
  end
end
