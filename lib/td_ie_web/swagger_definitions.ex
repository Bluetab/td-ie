defmodule TdIeWeb.SwaggerDefinitions do
  @moduledoc """
   Swagger definitions used by controllers
  """
  import PhoenixSwagger

  def ingest_definitions do
    %{
      Ingest:
        swagger_schema do
          title("Ingest")
          description("Ingest")

          properties do
            id(:integer, "unique identifier", required: true)

            ingest_version_id(
              :integer,
              "Ingest current version id",
              required: true
            )

            type(:string, "Ingest type", required: true)
            content(:object, "Ingest content", required: true)
            name(:string, "Ingest name", required: true)
            description(:object, "Ingest description", required: true)
            last_change_by(:integer, "Ingest last updated by", required: true)
            last_change_at(:string, "Ingest last updated date", required: true)
            domain(Schema.ref(:DomainRef))
            status(:string, "Ingest status", required: true)
            current(:boolean, "Is this the current version?", required: true)
            version(:integer, "Ingest version", required: true)
            reject_reason([:string, :null], "Ingest reject reason", required: false)

            mod_comments(
              [:string, :null],
              "Ingest modification comments",
              required: false
            )
          end
        end,
      IngestUpdate:
        swagger_schema do
          properties do
            ingest(
              Schema.new do
                properties do
                  content(:object, "Ingest content")
                  name(:string, "Ingest name")
                  description(:object, "Ingest description")
                end
              end
            )
          end
        end,
      IngestUpdateStatus:
        swagger_schema do
          properties do
            ingest(
              Schema.new do
                properties do
                  status(
                    :string,
                    "Ingest status (rejected, published, deprecated...)",
                    required: true
                  )

                  reject_reason([:string, :null], "Ingest reject reason")
                end
              end
            )
          end
        end,
      Ingests:
        swagger_schema do
          title("Ingests")
          description("A collection of Ingests")
          type(:array)
          items(Schema.ref(:Ingest))
        end,
      IngestResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Ingest))
          end
        end,
      IngestsResponse:
        swagger_schema do
          properties do
            data(
              Schema.new do
                properties do
                  collection(Schema.ref(:Ingests))
                end
              end
            )
          end
        end,
      DomainRef:
        swagger_schema do
          title("Domain Reference")
          description("A Domain's id and name")
          nullable(true)

          properties do
            id(:integer, "Domain Identifier", required: true)
            name(:string, "Domain Name", required: true)
          end

          example(%{
            id: 12,
            name: "Domain name"
          })
        end
    }
  end

  def ingest_execution_definitions do
    %{
      IngestExecution:
        swagger_schema do
          title("IngestExecution")
          description("IngestExecution")

          properties do
            id(:integer, "unique identifier", required: true)

            ingest_id(
              :integer,
              "Associated ingest id",
              required: true
            )

            status(:string, "Ingest execution status", required: true)
            start_timestamp(:string, "Ingest execution start timestamp", required: true)
            end_timestamp(:string, "Ingest execution end timestamp", required: true)
            description(:string, "Ingest execution description")
          end
        end,
      IngestExecutionUpdate:
        swagger_schema do
          properties do
            ingest_execution(
              Schema.new do
                properties do
                  status(:string, "Ingest execution status", required: true)
                  start_timestamp(:string, "Ingest execution start timestamp", required: true)
                  end_timestamp(:string, "Ingest execution end timestamp", required: true)
                  description(:string, "Ingest execution description")
                end
              end
            )
          end
        end,
      IngestExecutions:
        swagger_schema do
          title("Ingest executions")
          description("A collection of Ingest executions")
          type(:array)
          items(Schema.ref(:IngestExecution))
        end,
      IngestExecutionResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:IngestExecution))
          end
        end,
      IngestExecutionsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:IngestExecutions))
          end
        end,
      IngestExecutionByName:
        swagger_schema do
          properties do
            ingest_name(:string, "Ingest name")

            ingest_execution(
              Schema.new do
                properties do
                  status(:string, "Ingest execution status", required: true)
                  start_timestamp(:string, "Ingest execution start timestamp", required: true)
                  end_timestamp(:string, "Ingest execution end timestamp", required: true)
                  description(:string, "Ingest execution description")
                end
              end
            )
          end
        end,
      IngestExecutionByNameResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:IngestExecutionByName))
          end
        end
    }
  end

  def ingest_version_definitions do
    %{
      IngestVersion:
        swagger_schema do
          title("Ingest Version")
          description("Ingest Version")

          properties do
            id(:integer, "unique identifier", required: true)
            ingest_id(:integer, "Ingest unique id", required: true)
            type(:string, "Ingest type", required: true)
            content(:object, "Ingest Version content", required: true)
            name(:string, "Ingest Version name", required: true)
            description(:object, "Ingest Version description", required: true)
            last_change_by(:integer, "Ingest Version last change by", required: true)
            last_change_at(:string, "Ingest Version last change at", required: true)
            domain(Schema.ref(:DomainRef))
            status(:string, "Ingest Version status", required: true)
            current(:boolean, "Is this the current version?", required: true)
            version(:integer, "Ingest Version version number", required: true)

            reject_reason(
              [:string, :null],
              "Ingest Version rejection reason",
              required: false
            )

            mod_comments(
              [:string, :null],
              "Ingest Version modification comments",
              required: false
            )
          end
        end,
      IngestVersionUpdate:
        swagger_schema do
          properties do
            ingest_version(
              Schema.new do
                properties do
                  content(:object, "Ingest Version content")
                  name(:string, "Ingest Version name")
                  description(:object, "Ingest Version description")
                end
              end
            )
          end
        end,
      IngestVersions:
        swagger_schema do
          title("Ingest Versions")
          description("A collection of Ingest Versions")
          type(:array)
          items(Schema.ref(:IngestVersion))
        end,
      IngestVersionResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:IngestVersion))
          end
        end,
      IngestVersionsResponse:
        swagger_schema do
          properties do
            data(
              Schema.new do
                properties do
                  collection(Schema.ref(:IngestVersions))
                end
              end
            )
          end
        end,
      IngestVersionCreate:
        swagger_schema do
          properties do
            ingest_version(
              Schema.new do
                properties do
                  type(:string, "Ingest type (empty,...)", required: true)
                  content(:object, "Ingest content", required: true)
                  name(:string, "Ingest name", required: true)
                  description(:object, "Ingest description", required: true)
                  domain_id(:integer, "Ingest Domain ID", required: false)
                end
              end
            )
          end
        end,
      IngestVersionFilterRequest:
        swagger_schema do
          properties do
            query(:string, "Query string", required: false)
            filters(:object, "Filters", required: false)
          end

          example(%{
            query: "searchterm",
            filters: %{
              domain: ["Domain1", "Domain2"],
              status: ["draft"],
              data_owner: ["user1"]
            }
          })
        end,
      IngestField:
        swagger_schema do
          title("Ingest Field")
          description("Ingest Field representation")

          properties do
            id(:integer, "Ingest Field Id", required: true)
            ingest(:string, "Ingest", required: true)
            field(:object, "Data field", required: true)
          end
        end,
      IngestFields:
        swagger_schema do
          title("Ingest Fields")
          description("A collection of ingest fields")
          type(:array)
          items(Schema.ref(:IngestField))
        end,
      IngestFieldsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:IngestFields))
          end
        end
    }
  end

  def filter_swagger_definitions do
    %{
      FilterResponse:
        swagger_schema do
          title("Filters")

          description(
            "An object whose keys are filter names and values are arrays of filterable values"
          )

          properties do
            data(:object, "Filter values", required: true)
          end

          example(%{
            data: %{
              domain: ["Domain 1", "Domain 2"],
              language: ["Spanish", "English", "French"]
            }
          })
        end
    }
  end

  def template_swagger_definitions do
    %{
      Template:
        swagger_schema do
          title("Template")
          description("A Template")

          properties do
            label(:string, "Label", required: true)
            name(:string, "Name", required: true)
            content(:array, "Content", required: true)
            is_default(:boolean, "Is Default", required: true)
          end

          example(%{
            label: "Template 1",
            name: "Template1",
            content: [
              %{name: "name1", max_size: 100, type: "type1", required: true},
              %{related_area: "related_area1", max_size: 100, type: "type2", required: false}
            ],
            is_default: false
          })
        end,
      TemplateCreateUpdate:
        swagger_schema do
          properties do
            template(
              Schema.new do
                properties do
                  label(:string, "Label", required: true)
                  name(:string, "Name", required: true)
                  content(:array, "Content", required: true)
                  is_default(:boolean, "Is Default", required: true)
                end
              end
            )
          end
        end,
      Templates:
        swagger_schema do
          title("Templates")
          description("A collection of Templates")
          type(:array)
          items(Schema.ref(:Template))
        end,
      TemplateResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Template))
          end
        end,
      TemplatesResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Templates))
          end
        end,
      TemplateItem:
        swagger_schema do
          properties do
            name(:string, "Name", required: true)
          end
        end,
      TemplateItems:
        swagger_schema do
          type(:array)
          items(Schema.ref(:TemplateItem))
        end,
      AddTemplatesToDomain:
        swagger_schema do
          properties do
            templates(Schema.ref(:TemplateItems))
          end
        end
    }
  end

  def comment_swagger_definitions do
    %{
      Comment:
        swagger_schema do
          title("Comment")
          description("A Data Structure/Field Comment")

          properties do
            id(:integer, "Comment unique identifier", required: true)
            resource_id(:integer, "Resource identifier", required: true)
            resource_type(:string, "Resource type", required: true)
            user_id(:integer, "User identifier", required: true)
            content(:string, "Comment content", required: true)
          end

          example(%{
            resource_id: 123,
            resource_type: "Field",
            user_id: 1,
            content: "This is a comment"
          })
        end,
      CommentCreate:
        swagger_schema do
          properties do
            comment(
              Schema.new do
                properties do
                  resource_id(:integer, "Resource identifier", required: true)
                  resource_type(:string, "Resource type", required: true)
                  content(:string, "Comment content", required: true)
                end
              end
            )
          end
        end,
      CommentUpdate:
        swagger_schema do
          properties do
            comment(
              Schema.new do
                properties do
                  content(:string, "Comment content")
                end
              end
            )
          end
        end,
      Comments:
        swagger_schema do
          title("Comments")
          description("A collection of Comments")
          type(:array)
          items(Schema.ref(:Comment))
        end,
      CommentResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Comment))
          end
        end,
      CommentsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Comments))
          end
        end
    }
  end
end
