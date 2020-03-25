defmodule TdIeWeb.IngestVersionControllerTest do
  use TdIeWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import TdIeWeb.Authentication, only: :functions
  import TdIe.TaxonomyHelper, only: :functions

  alias TdIe.Ingests.Ingest
  alias TdIe.Permissions.MockPermissionResolver
  alias TdIeWeb.ApiServices.MockTdAuditService
  alias TdIeWeb.ApiServices.MockTdAuthService

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockTdAuditService)
    start_supervised(MockPermissionResolver)
    domain_fixture()
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "show" do
    @tag :admin_authenticated
    test "shows the specified ingest_version including it's name, description, domain and content",
         %{conn: conn} do
      Templates.create_template()
      domain_attrs = domain_fixture()
      ingest = insert(:ingest, domain_id: domain_attrs.id)

      ingest_version =
        insert(
          :ingest_version,
          ingest: ingest,
          content: %{"foo" => "bar"},
          name: "Concept Name",
          description: to_rich_text("The awesome ingest")
        )

      conn = get(conn, Routes.ingest_version_path(conn, :show, ingest_version.id))
      data = json_response(conn, 200)["data"]
      assert data["name"] == ingest_version.name
      assert data["description"] == ingest_version.description
      assert data["ingest_id"] == ingest_version.ingest.id
      assert data["content"] == ingest_version.content
      assert data["domain"]["id"] == ingest_version.ingest.domain_id
      assert data["domain"]["id"] == Map.get(domain_attrs, :id)
      assert data["domain"]["name"] == Map.get(domain_attrs, :name)
    end
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all ingest_versions", %{conn: conn} do
      conn = get(conn, Routes.ingest_version_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "search" do
    @tag :admin_authenticated
    test "find ingests by id and status", %{conn: conn} do
      published = Ingest.status().published
      draft = Ingest.status().draft
      Templates.create_template()
      domain_attrs = domain_fixture()
      id = [create_version(domain_attrs, "one", draft).ingest_id]
      id = [create_version(domain_attrs, "two", published).ingest_id | id]
      id = [create_version(domain_attrs, "three", published).ingest_id | id]

      conn =
        get(conn, Routes.ingest_path(conn, :search), %{
          id: Enum.join(id, ","),
          status: published
        })

      assert 2 == length(json_response(conn, 200)["data"])
    end
  end

  describe "create ingest" do
    @tag :admin_authenticated
    test "renders ingest when data is valid", %{conn: conn, swagger_schema: schema} do
      domain_attrs = domain_fixture()
      Templates.create_template()

      creation_attrs = %{
        content: %{},
        type: "some_type",
        name: "Some name",
        description: to_rich_text("Some description"),
        domain_id: Map.get(domain_attrs, :id),
        in_progress: false
      }

      conn =
        post(
          conn,
          Routes.ingest_version_path(conn, :create),
          ingest_version: creation_attrs
        )

      validate_resp_schema(conn, schema, "IngestVersionResponse")
      assert %{"ingest_id" => id} = json_response(conn, 201)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, Routes.ingest_path(conn, :show, id))
      validate_resp_schema(conn, schema, "IngestResponse")
      ingest = json_response(conn, 200)["data"]

      %{
        id: id,
        last_change_by: Integer.mod(:binary.decode_unsigned("app-admin"), 100_000),
        version: 1
      }
      |> Enum.each(&assert ingest |> Map.get(Atom.to_string(elem(&1, 0))) == elem(&1, 1))

      creation_attrs
      |> Map.drop([:domain_id])
      |> Enum.each(&assert ingest |> Map.get(Atom.to_string(elem(&1, 0))) == elem(&1, 1))

      assert ingest["domain"]["id"] == Map.get(domain_attrs, :id)
      assert ingest["domain"]["name"] == Map.get(domain_attrs, :name)
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn, swagger_schema: schema} do
      domain_attrs = domain_fixture()

      Templates.create_template(%{
        id: 0,
        name: "some_type",
        content: [],
        label: "label",
        scope: "ie"
      })

      creation_attrs = %{
        content: %{},
        type: "some_type",
        name: nil,
        description: to_rich_text("Some description"),
        domain_id: Map.get(domain_attrs, :id),
        in_progress: false
      }

      conn =
        post(
          conn,
          Routes.ingest_version_path(conn, :create),
          ingest_version: creation_attrs
        )

      validate_resp_schema(conn, schema, "IngestVersionResponse")
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "index_by_name" do
    @tag :admin_authenticated
    test "find ingest by name", %{conn: conn} do
      published = Ingest.status().published
      draft = Ingest.status().draft
      Templates.create_template()
      domain_attrs = domain_fixture()
      id = [create_version(domain_attrs, "one", draft).ingest.id]
      id = [create_version(domain_attrs, "two", published).ingest.id | id]
      [create_version(domain_attrs, "two", published).ingest.id | id]

      conn = get(conn, Routes.ingest_version_path(conn, :index), %{query: "two"})
      assert 2 == length(json_response(conn, 200)["data"])

      conn = recycle_and_put_headers(conn)
      conn = get(conn, Routes.ingest_version_path(conn, :index), %{query: "one"})
      assert 1 == length(json_response(conn, 200)["data"])
    end
  end

  describe "versions" do
    @tag :admin_authenticated
    test "lists ingest_versions", %{conn: conn} do
      Templates.create_template()
      ingest_version = insert(:ingest_version)

      conn =
        get(
          conn,
          Routes.ingest_version_ingest_version_path(conn, :versions, ingest_version.id)
        )

      [data | _] = json_response(conn, 200)["data"]
      assert data["name"] == ingest_version.name
    end
  end

  describe "create new versions" do
    @tag :admin_authenticated
    test "create new version with modified template", %{
      conn: conn
    } do
      template_content = [%{
        "name" => "group",
        "fields" => [%{"name" => "fieldname", "type" => "string", "required" => false}]
      }]

      template =
        Templates.create_template(%{
          id: 0,
          name: "onefield",
          content: template_content,
          label: "label",
          scope: "ie"
        })

      user = build(:user)

      ingest =
        insert(
          :ingest,
          type: template.name,
          last_change_by: user.id
        )

      ingest_version =
        insert(
          :ingest_version,
          ingest: ingest,
          last_change_by: user.id,
          status: Ingest.status().published
        )

      updated_content =
        template
        |> Map.get(:content)
        |> Enum.reduce([], fn field, acc ->
          [Map.put(field, "required", true) | acc]
        end)

      template
      |> Map.put(:content, updated_content)
      |> Templates.create_template()

      conn =
        post(
          conn,
          Routes.ingest_version_ingest_version_path(
            conn,
            :version,
            ingest_version.id
          )
        )

      assert json_response(conn, 201)["data"]
    end
  end

  describe "update ingest_version" do
    @tag :admin_authenticated
    test "renders ingest_version when data is valid", %{
      conn: conn,
      swagger_schema: schema
    } do
      Templates.create_template()
      user = build(:user)
      ingest_version = insert(:ingest_version, last_change_by: user.id)
      ingest_version_id = ingest_version.id

      update_attrs = %{
        content: %{},
        name: "The new name",
        description: to_rich_text("The new description"),
        in_progress: false
      }

      conn =
        put(
          conn,
          Routes.ingest_version_path(conn, :update, ingest_version),
          ingest_version: update_attrs
        )

      validate_resp_schema(conn, schema, "IngestVersionResponse")
      assert %{"id" => ^ingest_version_id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)
      conn = get(conn, Routes.ingest_version_path(conn, :show, ingest_version_id))
      validate_resp_schema(conn, schema, "IngestVersionResponse")

      updated_ingest_version = json_response(conn, 200)["data"]

      update_attrs
      |> Enum.each(
        &assert updated_ingest_version |> Map.get(Atom.to_string(elem(&1, 0))) == elem(&1, 1)
      )
    end
  end

  defp create_version(%{id: id}, name, status) do
    ingest = insert(:ingest, domain_id: id)

    insert(
      :ingest_version,
      ingest: ingest,
      name: name,
      status: status
    )
  end

  defp to_rich_text(plain) do
    %{"document" => plain}
  end
end
