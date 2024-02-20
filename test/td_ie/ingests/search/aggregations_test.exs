defmodule TdIe.Ingests.Search.AggregationsTest do
  use TdIe.DataCase

  alias TdCore.Search.ElasticDocumentProtocol
  alias TdIe.Ingests.IngestVersion

  describe "aggregations" do
    test "aggregations/0 returns aggregation terms of type user with size 50" do
      template_content = [
        %{
          "name" => "group",
          "fields" => [
            %{name: "fieldname", type: "string", cardinality: "?", values: %{}},
            %{name: "userfield", type: "user", cardinality: "?", values: %{}}
          ]
        }
      ]

      Templates.create_template(%{
        id: 0,
        name: "onefield",
        content: template_content,
        label: "label",
        scope: "ie"
      })

      aggs = ElasticDocumentProtocol.aggregations(%IngestVersion{})

      %{field: field, size: size} =
        aggs
        |> Map.get("userfield")
        |> Map.get(:terms)
        |> Map.take([:field, :size])

      assert size == 50
      assert field == "content.userfield.raw"
    end
  end
end
