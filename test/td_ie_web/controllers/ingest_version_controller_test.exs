defmodule TdIeWeb.IngestVersionControllerTest do
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
    Templates.create_template()
    [domain: domain]
  end

  setup %{conn: conn} do
    [conn: put_req_header(conn, "accept", "application/json")]
  end

  describe "GET /api/ingest_versions/:id" do
    @tag :admin_authenticated
    test "shows the specified ingest_version including it's name, description, domain and content",
         %{conn: conn, domain: domain} do
      %{id: domain_id, name: domain_name} = domain

      %{name: name, description: description, ingest_id: ingest_id, content: content} =
        ingest_version =
        insert(
          :ingest_version,
          ingest: build(:ingest, domain_id: domain_id),
          content: %{"foo" => "bar"},
          name: "Ingest Name",
          description: to_rich_text("The awesome ingest")
        )

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_version_path(conn, :show, ingest_version.id))
               |> json_response(:ok)

      assert %{
               "name" => ^name,
               "description" => ^description,
               "ingest_id" => ^ingest_id,
               "content" => ^content,
               "domain" => %{"id" => ^domain_id, "name" => ^domain_name}
             } = data
    end

    @tag :admin_authenticated
    test "excludes email and is_admin from last_change_user", %{conn: conn} do
      ingest_version = insert(:ingest_version, ingest: build(:ingest))

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_version_path(conn, :show, ingest_version.id))
               |> json_response(:ok)

      assert %{"last_change_user" => last_change_user} = data
      assert Map.keys(last_change_user) == ["full_name", "id", "user_name"]
    end
  end

  describe "GET /api/ingest_versions" do
    @tag :admin_authenticated
    test "lists all ingest_versions", %{conn: conn} do
      assert %{"data" => []} =
               conn
               |> get(Routes.ingest_version_path(conn, :index))
               |> json_response(:ok)
    end
  end

  describe "POST /api/ingest_versions/search" do
    @tag :admin_authenticated
    test "excludes email from last_change_by", %{conn: conn} do
      insert(:ingest_version)

      assert %{"data" => data} =
               conn
               |> post(Routes.ingest_version_path(conn, :search, %{}))
               |> json_response(:ok)

      assert [%{"last_change_by" => last_change_by}] = data
      assert Map.keys(last_change_by) == ["full_name", "id", "user_name"]
    end
  end

  describe "create ingest" do
    @tag :admin_authenticated
    test "renders ingest when data is valid", %{
      conn: conn,
      domain: domain,
      swagger_schema: schema
    } do
      %{id: domain_id, name: domain_name} = domain

      creation_attrs = %{
        "content" => %{},
        "type" => "some_type",
        "name" => "Some name",
        "description" => to_rich_text("Some description"),
        "domain_id" => domain_id,
        "in_progress" => false
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.ingest_version_path(conn, :create), ingest_version: creation_attrs)
               |> validate_resp_schema(schema, "IngestVersionResponse")
               |> json_response(:created)

      assert %{"ingest_id" => id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_path(conn, :show, id))
               |> validate_resp_schema(schema, "IngestResponse")
               |> json_response(:ok)

      assert %{"id" => ^id, "version" => 1} = data

      creation_attrs
      |> Map.delete("domain_id")
      |> Enum.each(&assert Map.get(data, elem(&1, 0)) == elem(&1, 1))

      assert data["domain"]["id"] == domain_id
      assert data["domain"]["name"] == domain_name
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{
      conn: conn,
      domain: domain,
      swagger_schema: schema
    } do
      %{id: domain_id} = domain

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
        domain_id: domain_id,
        in_progress: false
      }

      assert %{"errors" => errors} =
               conn
               |> post(Routes.ingest_version_path(conn, :create), ingest_version: creation_attrs)
               |> validate_resp_schema(schema, "IngestVersionResponse")
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end
  end

  describe "index_by_name" do
    @tag :admin_authenticated
    test "find ingest by name", %{conn: conn, domain: domain} do
      %{id: domain_id} = domain

      Enum.each(
        [{"one", "draft"}, {"two", "published"}, {"two", "published"}],
        fn {name, status} ->
          insert(:ingest_version, name: name, status: status, domain_id: domain_id)
        end
      )

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_version_path(conn, :index), %{query: "two"})
               |> json_response(:ok)

      assert length(data) == 2

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_version_path(conn, :index), %{query: "one"})
               |> json_response(:ok)

      assert length(data) == 1
    end
  end

  describe "versions" do
    @tag :admin_authenticated
    test "lists ingest_versions", %{conn: conn} do
      %{name: name} = ingest_version = insert(:ingest_version)

      assert %{"data" => data} =
               conn
               |> get(
                 Routes.ingest_version_ingest_version_path(conn, :versions, ingest_version.id)
               )
               |> json_response(:ok)

      assert [%{"name" => ^name} | _] = data
    end
  end

  describe "create new versions" do
    @tag :admin_authenticated
    test "create new version with modified template", %{conn: conn} do
      template_content = [
        %{
          "name" => "group",
          "fields" => [%{"name" => "fieldname", "type" => "string", "required" => false}]
        }
      ]

      template =
        Templates.create_template(%{
          id: 0,
          name: "onefield",
          content: template_content,
          label: "label",
          scope: "ie"
        })

      user = build(:user)

      ingest = insert(:ingest, type: template.name, last_change_by: user.id)

      ingest_version =
        insert(:ingest_version, ingest: ingest, last_change_by: user.id, status: "published")

      updated_content =
        template
        |> Map.get(:content)
        |> Enum.reduce([], fn field, acc ->
          [Map.put(field, "required", true) | acc]
        end)

      template
      |> Map.put(:content, updated_content)
      |> Templates.create_template()

      assert %{"data" => _data} =
               conn
               |> post(
                 Routes.ingest_version_ingest_version_path(conn, :version, ingest_version.id)
               )
               |> json_response(:created)
    end
  end

  describe "update ingest_version" do
    @tag :admin_authenticated
    test "renders ingest_version when data is valid", %{conn: conn, swagger_schema: schema} do
      user = build(:user)
      ingest_version = insert(:ingest_version, last_change_by: user.id)
      ingest_version_id = ingest_version.id

      update_attrs = %{
        "content" => %{},
        "name" => "The new name",
        "description" => to_rich_text("The new description"),
        "in_progress" => false
      }

      assert %{"data" => %{"id" => ^ingest_version_id}} =
               conn
               |> put(
                 Routes.ingest_version_path(conn, :update, ingest_version),
                 ingest_version: update_attrs
               )
               |> validate_resp_schema(schema, "IngestVersionResponse")
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_version_path(conn, :show, ingest_version_id))
               |> validate_resp_schema(schema, "IngestVersionResponse")
               |> json_response(:ok)

      update_attrs
      |> Enum.each(&assert Map.get(data, elem(&1, 0)) == elem(&1, 1))
    end
  end

  defp to_rich_text(plain) do
    %{"document" => plain}
  end
end
