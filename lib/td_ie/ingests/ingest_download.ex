defmodule TdIe.Ingest.Download do
  @moduledoc """
    Helper module to download ingests.
  """
  @df_cache Application.get_env(:td_ie, :df_cache)

  def to_csv(ingests) do
    ingests_by_type = Enum.group_by(ingests, &(&1 |> Map.get("template") |> Map.get("name")))
    types = Map.keys(ingests_by_type)
    templates_by_type = Enum.reduce(types, %{},  &Map.put(&2, &1, @df_cache.get_template_by_name(&1)))

    list = Enum.reduce(types, [], fn(type, acc) ->
      ingests = Map.get(ingests_by_type, type)
      template = Map.get(templates_by_type, type)

      csv_list = template_ingests_to_csv(template, ingests, !Enum.empty?(acc))
      acc ++ csv_list
    end)

    to_string(list)
  end

  defp template_ingests_to_csv(template, ingests, add_separation) do
    content = template.content
    content_names  = Enum.reduce(content, [], &(&2 ++ [Map.get(&1, "name")]))
    content_labels = Enum.reduce(content, [], &(&2 ++ [Map.get(&1, "label")]))
    content_names_to_types  = Enum.reduce(content, %{}, &Map.put(&2, Map.get(&1, "name"), Map.get(&1, "type")))

    headers = ["template", "name", "domain", "status", "description", "inserted_at"] ++ content_labels
    ingests_list = ingests_to_list(content_names, content_names_to_types, ingests)
    list_to_encode = case add_separation do
      true ->
        empty = build_empty_list([], length(headers))
        [empty, empty, headers] ++ ingests_list
      false -> [headers|ingests_list]
    end

    list_to_encode
    |> CSV.encode(separator: ?;)
    |> Enum.to_list
  end

  defp ingests_to_list(content_fields, _content_fields_to_types, ingests) do
    Enum.reduce(ingests, [], fn(ingest, acc) ->
      content = ingest["content"]
      values = [ingest["template"]["name"],
                ingest["name"],
                ingest["domain"]["name"],
                ingest["status"],
                ingest["description"],
                ingest["inserted_at"]]

      acc ++ [Enum.reduce(content_fields, values,
              &(&2 ++ [Map.get(content, &1, "")]))]
    end)
  end

  defp build_empty_list(acc, l) when l < 1, do: acc
  defp build_empty_list(acc, l), do: [""|build_empty_list(acc, l - 1)]
end
