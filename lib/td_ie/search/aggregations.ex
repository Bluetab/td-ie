defmodule TdIe.Search.Aggregations do
  @moduledoc """
  Aggregations for elasticsearch
  """

  alias TdCache.TemplateCache
  alias TdDfLib.Format

  def aggregation_terms do
    static_keywords = [
      {"domain", %{terms: %{field: "domain.name.raw", size: 50}}},
      {"domain_id", %{terms: %{field: "domain.id"}}},
      {"ingest_id", %{terms: %{field: "ingest_id"}}},
      {"domain_parents",
       %{
         nested: %{path: "domain_parents"},
         aggs: %{distinct_search: %{terms: %{field: "domain_parents.name.raw", size: 50}}}
       }},
      {"status", %{terms: %{field: "status"}}},
      {"current", %{terms: %{field: "current"}}},
      {"in_progress", %{terms: %{field: "in_progress"}}},
      {"template", %{terms: %{field: "template.label.raw", size: 50}}},
      {"execution_status", %{terms: %{field: "execution_status"}} }
    ]

    dynamic_keywords =
      TemplateCache.list_by_scope!("ie")
      |> Enum.flat_map(&template_terms/1)

    (static_keywords ++ dynamic_keywords)
    |> Enum.into(%{})
  end

  def template_terms(%{content: content}) do
    content
    |> Format.flatten_content_fields()
    |> Enum.filter(&filter_content_term/1)
    |> Enum.map(&Map.take(&1, ["name", "type"]))
    |> Enum.map(&content_term/1)
  end

  def filter_content_term(%{"type" => "list"}), do: true
  def filter_content_term(%{"values" => values}) when is_map(values), do: true
  def filter_content_term(_), do: false

  defp content_term(%{"name" => field, "type" => "user"}) do
    {field, %{terms: %{field: "content.#{field}.raw", size: 50}}}
  end

  defp content_term(%{"name" => field}) do
    {field, %{terms: %{field: "content.#{field}.raw"}}}
  end
end
