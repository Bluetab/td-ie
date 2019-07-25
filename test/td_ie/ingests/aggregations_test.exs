defmodule TdBg.Search.AggregationsTest do
  use TdIe.DataCase
  alias TdIe.Search.Aggregations
  alias TdCache.TemplateCache

  def create_template(template) do
    TemplateCache.put(template)
    template
  end

  describe "aggregation_terms" do
    test "aggregation_terms/0 returns aggregation terms of type user with size 50" do
      template_content = [
        %{name: "fieldname", type: "string", cardinality: "?", values: %{}},
        %{name: "userfield", type: "user", cardinality: "?", values: %{}}
      ]

      create_template(%{
        id: 0,
        name: "onefield",
        content: template_content,
        label: "label",
        scope: "ie"
      })

      aggs = Aggregations.aggregation_terms()

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
