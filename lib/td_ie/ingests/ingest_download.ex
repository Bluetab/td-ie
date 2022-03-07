defmodule TdIe.Ingests.Download do
  @moduledoc """
  Helper module to download ingests.
  """

  alias TdCache.TemplateCache
  alias TdDfLib.Format

  def to_csv(ingests) do
    ingests_by_type = Enum.group_by(ingests, &(&1 |> Map.get("template") |> Map.get("name")))
    types = Map.keys(ingests_by_type)

    templates_by_type = Enum.reduce(types, %{}, &Map.put(&2, &1, TemplateCache.get_by_name!(&1)))

    list =
      Enum.reduce(types, [], fn type, acc ->
        ingests = Map.get(ingests_by_type, type)
        template = Map.get(templates_by_type, type)

        csv_list = template_ingests_to_csv(template, ingests, !Enum.empty?(acc))
        acc ++ csv_list
      end)

    to_string(list)
  end

  defp template_ingests_to_csv(template, ingests, add_separation) do
    content =
      template
      |> Map.get(:content)
      |> Format.flatten_content_fields()

    content_fields = Enum.reduce(content, [], &(&2 ++ [Map.take(&1, ["name", "values", "type"])]))
    content_labels = Enum.reduce(content, [], &(&2 ++ [Map.get(&1, "label")]))

    headers =
      ["template", "name", "domain", "status", "description", "inserted_at"] ++ content_labels

    ingests_list = ingests_to_list(content_fields, ingests)

    list_to_encode =
      case add_separation do
        true ->
          empty = build_empty_list([], length(headers))
          [empty, empty, headers] ++ ingests_list

        false ->
          [headers | ingests_list]
      end

    list_to_encode
    |> CSV.encode(separator: ?;)
    |> Enum.to_list()
  end

  defp ingests_to_list(content_fields, ingests) do
    Enum.reduce(ingests, [], fn ingest, acc ->
      content = ingest["content"]

      values = [
        ingest["template"]["name"],
        ingest["name"],
        ingest["domain"]["name"],
        ingest["status"],
        ingest["description"],
        ingest["inserted_at"]
      ]

      acc ++ [Enum.reduce(content_fields, values, &(&2 ++ [&1 |> get_content_field(content)]))]
    end)
  end

  defp get_content_field(%{"type" => "url", "name" => name}, content) do
    content
    |> Map.get(name, [])
    |> content_to_list()
    |> Enum.map(&Map.get(&1, "url_value"))
    |> Enum.filter(&(not is_nil(&1)))
    |> Enum.join(", ")
  end

  defp get_content_field(
         %{
           "type" => "string",
           "name" => name,
           "values" => %{"fixed_tuple" => values}
         },
         content
       ) do
    content
    |> Map.get(name, [])
    |> content_to_list()
    |> Enum.map(fn map_value ->
      Enum.find(values, fn %{"value" => value} -> value == map_value end)
    end)
    |> Enum.map(&Map.get(&1, "text", ""))
    |> Enum.join(", ")
  end

  defp get_content_field(%{"type" => type, "name" => name}, content)
       when type in ["domain", "system"] do
    content
    |> Map.get(name, [])
    |> content_to_list()
    |> Enum.map(&Map.get(&1, "name"))
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp get_content_field(%{"type" => "table"}, _content), do: ""

  defp get_content_field(%{"name" => name}, content) do
    Map.get(content, name, "")
  end

  defp content_to_list(nil), do: []

  defp content_to_list([""]), do: []

  defp content_to_list(""), do: []

  defp content_to_list(content) when is_list(content), do: content

  defp content_to_list(content), do: [content]

  defp build_empty_list(acc, l) when l < 1, do: acc
  defp build_empty_list(acc, l), do: ["" | build_empty_list(acc, l - 1)]
end
