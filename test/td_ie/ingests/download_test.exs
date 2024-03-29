defmodule TdIe.Ingests.DownloadTests do
  @moduledoc """
  Test the download of ingests in a csv format
  """
  use TdIe.DataCase

  alias TdIe.Ingests.Download

  describe "ingest_download" do
    test "to_csv/1 return cvs content to download" do
      template_name = "template_name"
      field_name = "field_name"
      field_label = "field_label"
      hierarchy_name = "hierarchy_field_name"
      hierarchy_label = "hierarchy_label"

      Templates.create_template(%{
        id: 0,
        name: template_name,
        label: "label",
        scope: "ie",
        content: [
          %{
            "name" => "group",
            "fields" => [
              %{
                "name" => field_name,
                "type" => "list",
                "label" => field_label
              },
              %{
                "name" => "hierarchy_field_name",
                "label" => "hierarchy_label",
                "type" => "hierarchy",
                "cardinality" => "?",
                "values" => %{"hierarchy" => %{"id" => 1}}
              }
            ]
          }
        ]
      })

      ingest_name = "ingest_name"
      ingest_description = "ingest_description"
      domain_name = "domain_name"
      field_value = "field_value"
      hierarchy_value = ["23_4"]
      ingest_status = "draft"
      inserted_at = "2018-05-05"

      ingests = [
        %{
          "name" => ingest_name,
          "description" => ingest_description,
          "template" => %{"name" => template_name},
          "domain" => %{
            "name" => domain_name
          },
          "content" => %{
            field_name => field_value,
            hierarchy_name => hierarchy_value
          },
          "status" => ingest_status,
          "inserted_at" => inserted_at
        }
      ]

      csv = Download.to_csv(ingests)

      assert csv ==
               "template;name;domain;status;description;inserted_at;#{field_label};#{hierarchy_label}\r\n#{template_name};#{ingest_name};#{domain_name};#{ingest_status};#{ingest_description};#{inserted_at};#{field_value};\r\n"
    end
  end
end
