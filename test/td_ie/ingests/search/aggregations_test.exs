defmodule TdIe.Ingests.Search.AggregationsTest do
  use TdIe.DataCase

  alias TdCore.Search.ElasticDocumentProtocol
  alias TdIe.Ingests.IngestVersion

  @default_page 500

  describe "aggregations" do
    test "aggregations/0 returns aggregation terms of type user with size #{@default_page}" do
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

      assert size == @default_page
      assert field == "content.userfield.raw"
    end
  end
end
