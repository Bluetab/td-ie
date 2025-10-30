defmodule TdIe.Search.QueryTest do
  use ExUnit.Case

  alias TdIe.Search.Query

  describe "term/2" do
    test "creates term query for single value" do
      result = Query.term("status", "draft")

      assert result == %{term: %{"status" => "draft"}}
    end

    test "creates terms query for multiple values" do
      result = Query.term("status", ["draft", "published"])

      assert result == %{terms: %{"status" => ["draft", "published"]}}
    end

    test "sorts values in terms query" do
      result = Query.term("status", ["published", "draft"])

      assert result == %{terms: %{"status" => ["draft", "published"]}}
    end

    test "handles single value in list" do
      result = Query.term("status", ["draft"])

      assert result == %{term: %{"status" => "draft"}}
    end

    test "handles empty list" do
      result = Query.term("status", [])

      assert result == %{terms: %{"status" => []}}
    end
  end

  describe "should/2" do
    test "adds should clause to query" do
      query = %{query: %{match_all: %{}}}
      clause = %{term: %{"status" => "draft"}}

      result = Query.should(query, clause)

      assert result == %{query: %{match_all: %{}}, should: [clause]}
    end

    test "appends to existing should clauses" do
      query = %{query: %{match_all: %{}}, should: [%{term: %{"status" => "draft"}}]}
      clause = %{term: %{"type" => "ingest"}}

      result = Query.should(query, clause)

      assert result == %{
               query: %{match_all: %{}},
               should: [clause, %{term: %{"status" => "draft"}}]
             }
    end

    test "handles empty query" do
      query = %{}
      clause = %{term: %{"status" => "draft"}}

      result = Query.should(query, clause)

      assert result == %{should: [clause]}
    end
  end

  describe "must/2" do
    test "adds must clause to query" do
      query = %{query: %{match_all: %{}}}
      clause = %{term: %{"status" => "draft"}}

      result = Query.must(query, clause)

      assert result == %{query: %{match_all: %{}}, must: [clause]}
    end

    test "appends to existing must clauses" do
      query = %{query: %{match_all: %{}}, must: [%{term: %{"status" => "draft"}}]}
      clause = %{term: %{"type" => "ingest"}}

      result = Query.must(query, clause)

      assert result == %{
               query: %{match_all: %{}},
               must: [clause, %{term: %{"status" => "draft"}}]
             }
    end
  end

  describe "must_not/2" do
    test "adds must_not clause to query" do
      query = %{query: %{match_all: %{}}}
      clause = %{term: %{"status" => "deleted"}}

      result = Query.must_not(query, clause)

      assert result == %{query: %{match_all: %{}}, must_not: [clause]}
    end

    test "appends to existing must_not clauses" do
      query = %{query: %{match_all: %{}}, must_not: [%{term: %{"status" => "deleted"}}]}
      clause = %{term: %{"type" => "archived"}}

      result = Query.must_not(query, clause)

      assert result == %{
               query: %{match_all: %{}},
               must_not: [clause, %{term: %{"status" => "deleted"}}]
             }
    end
  end

  describe "put_clause/3" do
    test "adds clause to new key" do
      query = %{query: %{match_all: %{}}}
      clause = %{term: %{"status" => "draft"}}

      result = Query.put_clause(query, :filter, clause)

      assert result == %{query: %{match_all: %{}}, filter: [clause]}
    end

    test "appends clause to existing key" do
      query = %{query: %{match_all: %{}}, filter: [%{term: %{"status" => "draft"}}]}
      clause = %{term: %{"type" => "ingest"}}

      result = Query.put_clause(query, :filter, clause)

      assert result == %{
               query: %{match_all: %{}},
               filter: [clause, %{term: %{"status" => "draft"}}]
             }
    end

    test "handles empty query" do
      query = %{}
      clause = %{term: %{"status" => "draft"}}

      result = Query.put_clause(query, :filter, clause)

      assert result == %{filter: [clause]}
    end
  end

  describe "bool_query/1" do
    test "creates bool query with single clause" do
      clauses = %{must: [%{term: %{"status" => "draft"}}]}

      result = Query.bool_query(clauses)

      assert result == %{bool: %{must: %{term: %{"status" => "draft"}}}}
    end

    test "creates bool query with multiple clauses" do
      clauses = %{
        must: [%{term: %{"status" => "draft"}}],
        should: [%{term: %{"type" => "ingest"}}],
        must_not: [%{term: %{"deleted" => true}}]
      }

      result = Query.bool_query(clauses)

      assert result == %{
               bool: %{
                 must: %{term: %{"status" => "draft"}},
                 should: %{term: %{"type" => "ingest"}},
                 must_not: %{term: %{"deleted" => true}}
               }
             }
    end

    test "handles non-clause fields" do
      clauses = %{
        must: [%{term: %{"status" => "draft"}}],
        minimum_should_match: 1,
        boost: 2.0
      }

      result = Query.bool_query(clauses)

      assert result == %{
               bool: %{
                 must: %{term: %{"status" => "draft"}},
                 minimum_should_match: 1,
                 boost: 2.0
               }
             }
    end

    test "handles multiple values in clause" do
      clauses = %{
        must: [
          %{term: %{"status" => "draft"}},
          %{term: %{"type" => "ingest"}}
        ]
      }

      result = Query.bool_query(clauses)

      assert result == %{
               bool: %{
                 must: [
                   %{term: %{"status" => "draft"}},
                   %{term: %{"type" => "ingest"}}
                 ]
               }
             }
    end

    test "filters out unknown fields" do
      clauses = %{
        must: [%{term: %{"status" => "draft"}}],
        unknown_field: "value"
      }

      result = Query.bool_query(clauses)

      assert result == %{
               bool: %{
                 must: %{term: %{"status" => "draft"}}
               }
             }
    end

    test "handles empty clauses" do
      clauses = %{}

      result = Query.bool_query(clauses)

      assert result == %{bool: %{}}
    end
  end
end
