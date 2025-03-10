defmodule TdIeWeb.IngestVersionControllerTest do
  use TdIeWeb.ConnCase

  import Mox

  alias TdCore.Search.IndexWorkerMock

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    start_supervised!(TdIe.Cache.IngestLoader)
    :ok
  end

  setup do
    [template: CacheHelpers.insert_template(name: "some_type", scope: "ie")]
  end

  describe "GET /api/ingest_versions/:id" do
    @tag authentication: [role: "admin"]
    test "shows the specified ingest_version including name, description, domain and content",
         %{conn: conn, template: %{name: type}} do
      %{id: domain_id, name: domain_name} = CacheHelpers.put_domain()

      %{name: name, description: description, ingest_id: ingest_id, content: content} =
        ingest_version =
        insert(
          :ingest_version,
          ingest: build(:ingest, domain_id: domain_id, type: type),
          content: %{"list" => %{"value" => "two", "origin" => "user"}},
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
               "content" => %{"list" => "two"},
               "dynamic_content" => ^content,
               "domain" => %{"id" => ^domain_id, "name" => ^domain_name}
             } = data
    end

    @tag authentication: [role: "admin"]
    test "excludes email from last_change_user", %{conn: conn} do
      %{
        id: user_id,
        external_id: external_id,
        user_name: user_name,
        full_name: full_name,
        email: _
      } = CacheHelpers.put_user()

      ingest_version = insert(:ingest_version, last_change_by: user_id)

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_version_path(conn, :show, ingest_version.id))
               |> json_response(:ok)

      assert %{"last_change_user" => last_change_user} = data

      assert last_change_user == %{
               "id" => user_id,
               "external_id" => external_id,
               "user_name" => user_name,
               "full_name" => full_name
             }
    end
  end

  describe "GET /api/ingest_versions" do
    @tag authentication: [role: "admin"]
    test "lists all ingest_versions", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/ingests/_search", %{from: 0, size: 50, sort: sort, query: query}, opts ->
          assert opts == [params: %{"track_total_hits" => "true"}]
          assert sort == ["_score", "name.raw"]
          assert query == %{bool: %{must: %{match_all: %{}}}}
          SearchHelpers.hits_response([])
      end)

      assert %{"data" => []} =
               conn
               |> get(Routes.ingest_version_path(conn, :index))
               |> json_response(:ok)
    end
  end

  describe "POST /api/ingest_versions/search" do
    @tag authentication: [role: "admin"]
    test "excludes email from last_change_by", %{conn: conn} do
      %{
        id: user_id,
        full_name: full_name,
        external_id: external_id,
        user_name: user_name,
        email: _
      } = CacheHelpers.put_user()

      ingest_version = insert(:ingest_version, last_change_by: user_id)

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/ingests/_search", %{from: 0, size: 50, sort: sort, query: query}, opts ->
          assert opts == [params: %{"track_total_hits" => "true"}]
          assert sort == ["_score", "name.raw"]
          assert query == %{bool: %{must: %{match_all: %{}}}}
          SearchHelpers.hits_response([ingest_version])
      end)

      assert %{"data" => data} =
               conn
               |> post(Routes.ingest_version_path(conn, :search, %{}))
               |> json_response(:ok)

      assert [%{"last_change_by" => last_change_by}] = data

      assert last_change_by == %{
               "id" => user_id,
               "external_id" => external_id,
               "full_name" => full_name,
               "user_name" => user_name
             }
    end

    @tag authentication: [role: "admin"]
    test "excludes email from last_change_by with must params", %{conn: conn} do
      %{
        id: user_id,
        full_name: full_name,
        external_id: external_id,
        user_name: user_name,
        email: _
      } = CacheHelpers.put_user()

      ingest_version = insert(:ingest_version, last_change_by: user_id)

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/ingests/_search", %{from: 0, size: 50, sort: sort, query: query}, opts ->
          assert opts == [params: %{"track_total_hits" => "true"}]
          assert sort == ["_score", "name.raw"]
          assert query == %{bool: %{must: %{match_all: %{}}}}
          SearchHelpers.hits_response([ingest_version])
      end)

      assert %{"data" => data} =
               conn
               |> post(Routes.ingest_version_path(conn, :search), %{"must" => %{}})
               |> json_response(:ok)

      assert [%{"last_change_by" => last_change_by}] = data

      assert last_change_by == %{
               "id" => user_id,
               "external_id" => external_id,
               "full_name" => full_name,
               "user_name" => user_name
             }
    end
  end

  describe "create ingest" do
    @tag authentication: [role: "admin"]
    test "renders ingest when data is valid", %{conn: conn} do
      IndexWorkerMock.clear()
      %{id: domain_id, name: domain_name} = CacheHelpers.put_domain()

      creation_attrs = %{
        "content" => %{"foo" => %{"value" => "bar", "origin" => "user"}},
        "type" => "some_type",
        "name" => "Some name",
        "description" => to_rich_text("Some description"),
        "domain_id" => domain_id,
        "in_progress" => false
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.ingest_version_path(conn, :create), ingest_version: creation_attrs)
               |> json_response(:created)

      assert %{"ingest_id" => id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_path(conn, :show, id))
               |> json_response(:ok)

      assert %{"id" => ^id, "version" => 1} = data

      assert data["content"] == %{"foo" => "bar"}
      assert data["dynamic_content"] == creation_attrs["content"]
      assert data["description"] == creation_attrs["description"]
      assert data["in_progress"] == creation_attrs["in_progress"]
      assert data["name"] == creation_attrs["name"]
      assert data["type"] == creation_attrs["type"]

      assert data["domain"]["id"] == domain_id
      assert data["domain"]["name"] == domain_name
      assert [{:reindex, :ingests, [_]}] = IndexWorkerMock.calls()
      IndexWorkerMock.clear()
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{
      conn: conn
    } do
      %{id: domain_id} = CacheHelpers.put_domain()

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
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end
  end

  describe "index_by_name" do
    @tag authentication: [role: "admin"]
    test "find ingest by name", %{conn: conn} do
      %{id: domain_id} = CacheHelpers.put_domain()

      %{id: id} =
        one = insert(:ingest_version, name: "one", status: "draft", domain_id: domain_id)

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/ingests/_search", %{from: 0, size: 50, sort: sort, query: query}, opts ->
          assert opts == [params: %{"track_total_hits" => "true"}]
          assert sort == ["_score", "name.raw"]

          assert %{
                   bool: %{
                     must: %{
                       multi_match: %{
                         fields: ["ngram_name*^3", "content.string"],
                         lenient: true,
                         query: "one",
                         type: "bool_prefix",
                         fuzziness: "AUTO"
                       }
                     }
                   }
                 } = query

          SearchHelpers.hits_response([one])
      end)

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_version_path(conn, :index), %{query: "one"})
               |> json_response(:ok)

      assert [%{"id" => ^id}] = data
    end

    @tag authentication: [role: "admin"]
    test "find ingest by name searching by wildcard", %{conn: conn} do
      %{id: domain_id} = CacheHelpers.put_domain()

      %{id: id} =
        one = insert(:ingest_version, name: "one", status: "draft", domain_id: domain_id)

      expect(ElasticsearchMock, :request, fn
        _, :post, "/ingests/_search", %{from: 0, size: 50, sort: sort, query: query}, opts ->
          assert opts == [params: %{"track_total_hits" => "true"}]
          assert sort == ["_score", "name.raw"]

          assert %{
                   bool: %{
                     must: %{
                       simple_query_string: %{fields: ["name*"], query: "\"one\""}
                     }
                   }
                 } = query

          SearchHelpers.hits_response([one])
      end)

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_version_path(conn, :index), %{query: "\"one\""})
               |> json_response(:ok)

      assert [%{"id" => ^id}] = data
    end
  end

  describe "versions" do
    @tag authentication: [role: "admin"]
    test "lists ingest_versions", %{conn: conn} do
      %{name: name, ingest_id: ingest_id} = ingest_version = insert(:ingest_version)

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/ingests/_search", %{from: 0, size: 50, sort: sort, query: query}, opts ->
          assert opts == [params: %{"track_total_hits" => "true"}]
          assert sort == ["_score", "name.raw"]

          assert query == %{
                   bool: %{
                     must: %{term: %{"ingest_id" => ingest_id}}
                   }
                 }

          SearchHelpers.hits_response([ingest_version])
      end)

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
    @tag authentication: [role: "admin"]
    test "create new version with modified template", %{conn: conn} do
      IndexWorkerMock.clear()

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

      on_exit(fn ->
        IndexWorkerMock.clear()
        Templates.delete_template(template.id)
      end)

      %{user_id: user_id} = build(:claims)

      ingest = insert(:ingest, type: template.name, last_change_by: user_id)

      ingest_version =
        insert(:ingest_version, ingest: ingest, last_change_by: user_id, status: "published")

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

      assert [{:reindex, :ingests, [_]}] = IndexWorkerMock.calls()
    end
  end

  describe "update ingest_version" do
    @tag authentication: [role: "admin"]
    test "renders ingest_version when data is valid", %{conn: conn} do
      IndexWorkerMock.clear()
      %{user_id: user_id} = build(:claims)
      %{id: id} = insert(:ingest_version, last_change_by: user_id)

      update_attrs = %{
        "content" => %{},
        "name" => "The new name",
        "description" => to_rich_text("The new description"),
        "in_progress" => false
      }

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(
                 Routes.ingest_version_path(conn, :update, id),
                 ingest_version: update_attrs
               )
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_version_path(conn, :show, id))
               |> json_response(:ok)

      Enum.each(update_attrs, &assert(Map.get(data, elem(&1, 0)) == elem(&1, 1)))
      assert [{:reindex, :ingests, [_]}] = IndexWorkerMock.calls()
      IndexWorkerMock.clear()
    end
  end

  defp to_rich_text(plain) do
    %{"document" => plain}
  end
end
