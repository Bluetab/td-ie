defmodule TdIe.Ingests.IngestVersionTest do
  use TdIe.DataCase

  alias Ecto.Changeset
  alias TdIe.Ingests.IngestVersion

  setup do
    identifier_name = "identifier"

    with_identifier = %{
      id: System.unique_integer([:positive]),
      name: "Ingesta template with identifier field",
      label: "ingesta_with_identifier",
      scope: "ie",
      content: [
        %{
          "fields" => [
            %{
              "cardinality" => "1",
              "default" => "",
              "label" => "Identifier",
              "name" => identifier_name,
              "subscribable" => false,
              "type" => "string",
              "values" => nil,
              "widget" => "identifier"
            },
            %{
              "cardinality" => "1",
              "default" => "",
              "label" => "Text",
              "name" => "text",
              "subscribable" => false,
              "type" => "string",
              "values" => nil,
              "widget" => "text"
            }
          ],
          "name" => ""
        }
      ]
    }

    without_identifier = %{
      id: System.unique_integer([:positive]),
      name: "Ingesta template without identifier field",
      label: "ingesta_without_identifier",
      scope: "ie",
      content: [
        %{
          "fields" => [
            %{
              "cardinality" => "1",
              "default" => "",
              "label" => "Text",
              "name" => "text",
              "subscribable" => false,
              "type" => "string",
              "values" => nil,
              "widget" => "text"
            }
          ],
          "name" => ""
        }
      ]
    }

    template_with_identifier = CacheHelpers.insert_template(with_identifier)
    template_without_identifier = CacheHelpers.insert_template(without_identifier)

    [
      template_with_identifier: template_with_identifier,
      template_without_identifier: template_without_identifier,
      identifier_name: identifier_name
    ]
  end

  describe "create_changeset/2" do
    test "puts a new identifier if the template has an identifier field", %{
      template_with_identifier: template_with_identifier,
      identifier_name: identifier_name
    } do
      attrs = %{
        content: %{},
        content_schema: template_with_identifier.content,
        description: %{},
        domain_id: 384,
        ingest: %{
          domain_id: 384,
          last_change_by: 467,
          type: template_with_identifier.name
        },
        last_change_at: ~U[2021-12-07 14:39:04.196316Z],
        last_change_by: 467,
        name: "td-dd",
        status: "draft",
        type: template_with_identifier.name,
        version: 1
      }

      assert %Changeset{changes: changes} =
               IngestVersion.create_changeset(%IngestVersion{}, attrs)

      assert %{content: new_content} = changes
      assert %{^identifier_name => _identifier} = new_content
    end

    test "avoids putting new identifier if template lacks an identifier field", %{
      template_without_identifier: template_without_identifier,
      identifier_name: identifier_name
    } do
      attrs = %{
        content: %{},
        content_schema: template_without_identifier.content,
        description: %{},
        domain_id: 384,
        ingest: %{
          domain_id: 384,
          last_change_by: 467,
          type: template_without_identifier.name
        },
        last_change_at: ~U[2021-12-07 14:39:04.196316Z],
        last_change_by: 467,
        name: "td-dd",
        status: "draft",
        type: template_without_identifier.name,
        version: 1
      }

      assert %Changeset{changes: changes} =
               IngestVersion.create_changeset(%IngestVersion{}, attrs)

      assert %{content: new_content} = changes
      refute match?(%{^identifier_name => _identifier}, new_content)
    end
  end

  describe "update_changeset/2" do
    test "keeps an already present identifier (i.e., editing)", %{
      template_with_identifier: template_with_identifier,
      identifier_name: identifier_name
    } do
      # Existing identifier previously put by the create changeset
      existing_identifier = "00000000-0000-0000-0000-000000000000"
      ingest = build(:ingest, %{type: template_with_identifier.name})

      ingest_version =
        build(:ingest_version, ingest: ingest, content: %{identifier_name => existing_identifier})

      assert %Changeset{changes: changes} =
               IngestVersion.update_changeset(ingest_version, %{
                 content: %{"text" => "some update"}
               })

      assert %{content: new_content} = changes
      assert %{^identifier_name => ^existing_identifier} = new_content
    end

    test "keeps an already present identifier (i.e., editing) if extraneous identifier attr is passed",
         %{
           template_with_identifier: template_with_identifier,
           identifier_name: identifier_name
         } do
      # Existing identifier previously put by the create changeset
      existing_identifier = "00000000-0000-0000-0000-000000000000"
      ingest = build(:ingest, %{type: template_with_identifier.name})

      ingest_version =
        build(:ingest_version, %{
          ingest: ingest,
          content: %{identifier_name => existing_identifier}
        })

      assert %Changeset{changes: changes} =
               IngestVersion.update_changeset(ingest_version, %{
                 content: %{
                   "text" => "some update",
                   identifier_name => "11111111-1111-1111-1111-111111111111"
                 }
               })

      assert %{content: new_content} = changes
      assert %{^identifier_name => ^existing_identifier} = new_content
    end

    test "puts an identifier if there is not already one and the template has an identifier field",
         %{template_with_identifier: template_with_identifier, identifier_name: identifier_name} do
      # Ingest version has no identifier but its template does
      # This happens if identifier is added to template after ingest creation
      # Test an update to the ingest version in this state.
      ingest = build(:ingest, %{type: template_with_identifier.name})
      %{content: content} = ingest_version = build(:ingest_version, %{ingest: ingest})
      # Just to make sure factory does not add identifier
      refute match?(%{^identifier_name => _identifier}, content)

      assert %Changeset{changes: changes} =
               IngestVersion.update_changeset(ingest_version, %{
                 content: %{"text" => "some update"}
               })

      assert %{content: new_content} = changes
      assert %{^identifier_name => _identifier} = new_content
    end
  end
end
