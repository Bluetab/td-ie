defmodule TdIe.Search.Mappings do
  @moduledoc """
  Generates mappings for elasticsearch
  """

  alias TdCache.TemplateCache
  alias TdDfLib.Format

  @raw %{raw: %{type: "keyword"}}
  @raw_sort %{raw: %{type: "keyword"}, sort: %{type: "keyword", normalizer: "sortable"}}

  def get_mappings do
    content_mappings = %{properties: get_dynamic_mappings()}

    mapping_type = %{
      id: %{type: "long"},
      name: %{type: "text", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      description: %{type: "text"},
      version: %{type: "short"},
      template: %{
        properties: %{
          name: %{type: "text"},
          label: %{type: "text", fields: @raw}
        }
      },
      status: %{type: "keyword"},
      last_change_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      current: %{type: "boolean"},
      in_progress: %{type: "boolean"},
      domain: %{
        properties: %{
          id: %{type: "long"},
          name: %{type: "text", fields: @raw_sort}
        }
      },
      last_change_by: %{
        properties: %{
          id: %{type: "long"},
          user_name: %{type: "text", fields: @raw},
          full_name: %{type: "text", fields: @raw}
        }
      },
      domain_ids: %{type: "long"},
      execution_status: %{type: "text", fields: @raw_sort},
      last_execution: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      content: content_mappings
    }

    settings = %{
      number_of_shards: 1,
      analysis: %{
        normalizer: %{
          sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
        }
      }
    }

    %{mappings: %{properties: mapping_type}, settings: settings}
  end

  def get_dynamic_mappings do
    TemplateCache.list_by_scope!("ie")
    |> Enum.flat_map(&get_mappings/1)
    |> Enum.into(%{})
  end

  defp get_mappings(%{content: content}) do
    content
    |> Format.flatten_content_fields()
    |> Enum.map(fn field ->
      field
      |> field_mapping
      |> maybe_boost(field)
      |> maybe_disable_search(field)
    end)
  end

  defp field_mapping(%{"name" => name, "type" => "table"}) do
    {name, %{enabled: false}}
  end

  defp field_mapping(%{"name" => name, "type" => "url"}) do
    {name, %{enabled: false}}
  end

  defp field_mapping(%{"name" => name, "type" => "copy"}) do
    {name, %{enabled: false}}
  end

  defp field_mapping(%{"name" => name, "type" => "enriched_text"}) do
    {name, mapping_type("enriched_text")}
  end

  defp field_mapping(%{"name" => name, "widget" => "identifier"}) do
    {name, %{type: "keyword"}}
  end

  defp field_mapping(%{"name" => name, "type" => "domain"}) do
    {name, %{type: "long"}}
  end

  defp field_mapping(%{"name" => name, "type" => "system"}) do
    {name,
     %{
       type: "nested",
       properties: %{
         id: %{type: "long"},
         name: %{type: "text", fields: @raw},
         external_id: %{type: "text", fields: @raw}
       }
     }}
  end

  defp field_mapping(%{"name" => name, "values" => values}) do
    {name, mapping_type(values)}
  end

  defp field_mapping(%{"name" => name}) do
    {name, mapping_type("string")}
  end

  defp maybe_boost(field_tuple, %{"boost" => boost}) when boost in ["", "1"], do: field_tuple

  defp maybe_boost({name, field_value}, %{"boost" => boost}) do
    {boost_float, _} = Float.parse(boost)
    {name, Map.put(field_value, :boost, boost_float)}
  end

  defp maybe_boost(field_tuple, _), do: field_tuple

  defp maybe_disable_search({name, field_value}, %{"searchable" => false}) do
    {name, Map.drop(field_value, [:fields])}
  end

  defp maybe_disable_search(field_tuple, _), do: field_tuple

  defp mapping_type(values) when is_map(values) do
    %{type: "text", fields: @raw}
  end

  defp mapping_type(_default), do: %{type: "text"}
end
