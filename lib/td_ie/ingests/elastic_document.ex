defmodule TdIe.Ingests.ElasticDocument do
  @moduledoc """
  Elasticsearch mapping and aggregation
  definition for Ingests
  """

  alias Elasticsearch.Document
  alias TdCore.Search.Cluster
  alias TdCore.Search.ElasticDocument
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdIe.Ingests
  alias TdIe.Ingests.IngestVersion

  defimpl Document, for: IngestVersion do
    use ElasticDocument

    alias TdCache.TaxonomyCache
    alias TdCache.TemplateCache
    alias TdCache.UserCache
    alias TdDfLib.Format
    alias TdDfLib.RichText

    @impl Elasticsearch.Document
    def id(%IngestVersion{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(%IngestVersion{ingest: ingest} = iv) do
      %{type: type, domain_id: domain_id, executions: executions} = ingest

      template = TemplateCache.get_by_name!(type) || %{content: []}
      domain = get_domain(domain_id)
      domain_ids = List.wrap(domain_id)
      last_execution = Ingests.get_last_execution(executions)

      content =
        iv
        |> Map.get(:content)
        |> Format.search_values(template, domain_id: domain_id)
        |> Enum.map(fn {key, %{"value" => value}} -> {key, value} end)
        |> Map.new()

      iv
      |> Map.take([
        :id,
        :ingest_id,
        :name,
        :status,
        :version,
        :last_change_at,
        :current,
        :in_progress,
        :inserted_at
      ])
      |> Map.put(:content, content)
      |> Map.put(:description, RichText.to_plain_text(iv.description))
      |> Map.put(:domain, Map.take(domain, [:id, :name, :external_id]))
      |> Map.put(:domain_ids, domain_ids)
      |> Map.put(:last_change_by, get_last_change_by(iv))
      |> Map.put(:template, Map.take(template, [:name, :label]))
      |> Map.put(:execution_status, Map.get(last_execution, :status))
      |> Map.put(:last_execution, Map.get(last_execution, :execution))
    end

    defp get_domain(id) when is_integer(id) do
      case TaxonomyCache.get_domain(id) do
        %{} = domain -> Map.take(domain, [:id, :external_id, :name])
        nil -> %{id: id}
      end
    end

    defp get_domain(_id), do: %{}

    defp get_last_change_by(%IngestVersion{last_change_by: last_change_by}) do
      get_user(last_change_by)
    end

    defp get_user(user_id) do
      case UserCache.get(user_id) do
        {:ok, nil} -> %{}
        {:ok, %{} = user} -> Map.delete(user, :email)
      end
    end
  end

  defimpl ElasticDocumentProtocol, for: IngestVersion do
    use ElasticDocument

    def mappings(_) do
      content_mappings = %{properties: get_dynamic_mappings("ie")}

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

    def aggregations(_) do
      %{
        "domain" => %{terms: %{field: "domain.name.raw", size: Cluster.get_size_field("domain")}},
        "domain_id" => %{terms: %{field: "domain.id", size: Cluster.get_size_field("domain_id")}},
        "ingest_id" => %{terms: %{field: "ingest_id", size: Cluster.get_size_field("ingest_id")}},
        "status" => %{terms: %{field: "status", size: Cluster.get_size_field("status")}},
        "current" => %{terms: %{field: "current", size: Cluster.get_size_field("current")}},
        "in_progress" => %{
          terms: %{field: "in_progress", size: Cluster.get_size_field("in_progress")}
        },
        "template" => %{
          terms: %{field: "template.label.raw", size: Cluster.get_size_field("template")}
        },
        "execution_status" => %{
          terms: %{
            field: "execution_status.raw",
            size: Cluster.get_size_field("execution_status")
          }
        },
        "taxonomy" => %{terms: %{field: "domain_ids", size: Cluster.get_size_field("taxonomy")}}
      }
      |> merge_dynamic_fields("ie", "content")
    end
  end
end
