defmodule TdIeWeb.IngestFilterControllerTest do
  @moduledoc """
  Testing of ingest filter controller
  """
  use TdIeWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import Mox

  setup :verify_on_exit!

  setup do
    start_supervised!(TdIe.Search.Cluster)
    :ok
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all filters (admin user)", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/ingests/_search", %{aggs: _, query: query, size: 0}, [] ->
          assert query == %{bool: %{filter: %{match_all: %{}}}}
          SearchHelpers.aggs_response()
      end)

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_filter_path(conn, :index))
               |> json_response(:ok)

      assert data == %{"foo" => ["bar", "baz"]}
    end

    @tag authentication: [user_name: "not_an_admin", permissions: ["view_published_ingests"]]
    test "lists all filters (regular user)", %{conn: conn, domain_id: domain_id} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/ingests/_search", %{aggs: _, query: query, size: 0}, [] ->
          assert query == %{
                   bool: %{
                     filter: %{
                       bool: %{
                         filter: [
                           %{term: %{"status" => "published"}},
                           %{term: %{"domain_ids" => domain_id}}
                         ]
                       }
                     }
                   }
                 }

          SearchHelpers.aggs_response()
      end)

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_filter_path(conn, :index))
               |> json_response(:ok)

      assert data == %{"foo" => ["bar", "baz"]}
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "lists all filters (user with no permissions)", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/ingests/_search", %{aggs: _, query: query, size: 0}, [] ->
          assert query == %{bool: %{filter: %{match_none: %{}}}}
          SearchHelpers.aggs_response()
      end)

      assert %{"data" => data} =
               conn
               |> get(Routes.ingest_filter_path(conn, :index))
               |> json_response(:ok)

      assert data == %{"foo" => ["bar", "baz"]}
    end
  end
end
