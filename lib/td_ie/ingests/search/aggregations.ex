defmodule TdIe.Ingests.Search.Aggregations do
  @moduledoc """
  Aggregations for elasticsearch
  """

  alias TdCache.TemplateCache
  alias TdDfLib.Format

  def aggregations do
    static_keywords = [
      {"domain", %{terms: %{field: "domain.name.raw", size: 50}}},
      {"domain_id", %{terms: %{field: "domain.id"}}},
      {"ingest_id", %{terms: %{field: "ingest_id"}}},
      {"status", %{terms: %{field: "status"}}},
      {"current", %{terms: %{field: "current"}}},
      {"in_progress", %{terms: %{field: "in_progress"}}},
      {"template", %{terms: %{field: "template.label.raw", size: 50}}},
      {"execution_status", %{terms: %{field: "execution_status.raw", size: 50}}},
      {"taxonomy", %{terms: %{field: "domain_ids", size: 500}}}
    ]

    dynamic_keywords =
      TemplateCache.list_by_scope!("ie")
      |> Enum.flat_map(&template_terms/1)

    (static_keywords ++ dynamic_keywords)
    |> Enum.into(%{})
  end

  defp template_terms(%{content: content}) do
    content
    |> Format.flatten_content_fields()
    |> Enum.filter(&filter_content_term/1)
    |> Enum.map(&Map.take(&1, ["name", "type"]))
    |> Enum.map(&content_term/1)
  end

  defp filter_content_term(%{"type" => "domain"}), do: true
  defp filter_content_term(%{"type" => "system"}), do: true
  defp filter_content_term(%{"values" => values}) when is_map(values), do: true
  defp filter_content_term(_), do: false

  defp content_term(%{"name" => field, "type" => "user"}) do
    {field, %{terms: %{field: "content.#{field}.raw", size: 50}}}
  end

  defp content_term(%{"name" => field, "type" => "domain"}) do
    {field, %{terms: %{field: "content.#{field}", size: 50}, meta: %{type: "domain"}}}
  end

  defp content_term(%{"name" => field, "type" => "system"}) do
    {field,
     %{
       nested: %{path: "content.#{field}"},
       aggs: %{distinct_search: %{terms: %{field: "content.#{field}.external_id.raw", size: 50}}}
     }}
  end

  defp content_term(%{"name" => field}) do
    {field, %{terms: %{field: "content.#{field}.raw"}}}
  end
end
