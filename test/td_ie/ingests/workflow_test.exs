defmodule TdIe.Ingests.WorkflowTest do
  use TdIe.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdIe.Cache.IngestLoader
  alias TdIe.Ingests
  alias TdIe.Ingests.IngestVersion
  alias TdIe.Ingests.Workflow
  alias TdIe.Search.IndexWorker

  @stream TdCache.Audit.stream()

  setup_all do
    Redix.del!(@stream)
    start_supervised(IngestLoader)
    start_supervised(IndexWorker)
    [claims: build(:claims)]
  end

  setup do
    on_exit(fn -> Redix.del!(@stream) end)
    :ok
  end

  describe "create_ingest/1" do
    test "with valid data creates a ingest", %{claims: %{user_id: user_id}} do
      domain_id = 1

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user_id,
        last_change_at: DateTime.utc_now()
      }

      version_attrs = %{
        ingest: ingest_attrs,
        content: %{},
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user_id,
        last_change_at: DateTime.utc_now(),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, [])

      assert {:ok, %{ingest_version: ingest_version}} = Workflow.create_ingest(creation_attrs)

      assert ingest_version.content == version_attrs.content
      assert ingest_version.name == version_attrs.name
      assert ingest_version.description == version_attrs.description
      assert ingest_version.last_change_by == version_attrs.last_change_by
      assert ingest_version.current == true
      assert ingest_version.version == version_attrs.version
      assert ingest_version.in_progress == false
      assert ingest_version.ingest.type == ingest_attrs.type
      assert ingest_version.ingest.domain_id == ingest_attrs.domain_id
      assert ingest_version.ingest.last_change_by == ingest_attrs.last_change_by
    end

    test "publishes an audit event including domain_id", %{claims: %{user_id: user_id}} do
      domain_id = 1

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user_id,
        last_change_at: DateTime.utc_now()
      }

      version_attrs = %{
        ingest: ingest_attrs,
        content: %{},
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user_id,
        last_change_at: DateTime.utc_now(),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, [])

      assert {:ok, %{audit: [event_id]}} = Workflow.create_ingest(creation_attrs)
      assert {:ok, [%{id: ^event_id} = event]} = Stream.read(:redix, @stream, transform: true)
      assert %{payload: payload} = event
      assert %{"ingest" => %{"domain_id" => ^domain_id}} = Jason.decode!(payload)
    end

    test "with invalid data returns error changeset" do
      version_attrs = %{
        ingest: nil,
        content: %{},
        name: nil,
        description: nil,
        last_change_by: nil,
        last_change_at: nil,
        version: nil
      }

      creation_attrs = Map.put(version_attrs, :content_schema, [])

      assert {:error, :ingest_version, %Ecto.Changeset{}, _} =
               Workflow.create_ingest(creation_attrs)
    end

    test "with content", %{claims: %{user_id: user_id}} do
      domain_id = 1

      content_schema = [
        %{"name" => "Field1", "type" => "string"},
        %{"name" => "Field2", "type" => "list", "values" => ["Hello", "World"]},
        %{"name" => "Field3", "type" => "variable_list"}
      ]

      content = %{"Field1" => "Hello", "Field2" => "World", "Field3" => ["Hellow", "World"]}

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user_id,
        last_change_at: DateTime.utc_now()
      }

      version_attrs = %{
        ingest: ingest_attrs,
        content: content,
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user_id,
        last_change_at: DateTime.utc_now(),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, content_schema)

      assert {:ok, %{ingest_version: ingest_version}} = Workflow.create_ingest(creation_attrs)

      assert %{content: ^content} = ingest_version
    end

    test "with invalid content: required", %{claims: %{user_id: user_id}} do
      domain_id = 1

      content_schema = [
        %{"name" => "Field1", "type" => "string", "cardinality" => "1"},
        %{"name" => "Field2", "type" => "string", "cardinality" => "1"}
      ]

      content = %{}

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user_id,
        last_change_at: DateTime.utc_now()
      }

      version_attrs = %{
        ingest: ingest_attrs,
        content: content,
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user_id,
        last_change_at: DateTime.utc_now(),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, content_schema)

      assert {:ok, %{ingest_version: ingest_version}} = Workflow.create_ingest(creation_attrs)

      assert ingest_version.content == version_attrs.content
      assert ingest_version.name == version_attrs.name
      assert ingest_version.description == version_attrs.description
      assert ingest_version.last_change_by == version_attrs.last_change_by
      assert ingest_version.current == true
      assert ingest_version.in_progress == true
      assert ingest_version.version == version_attrs.version
      assert ingest_version.ingest.type == ingest_attrs.type
      assert ingest_version.ingest.domain_id == ingest_attrs.domain_id
      assert ingest_version.ingest.last_change_by == ingest_attrs.last_change_by
    end

    test "with content: default values", %{claims: %{user_id: user_id}} do
      domain_id = 1

      content_schema = [
        %{"name" => "Field1", "type" => "string", "default" => "Hello"},
        %{"name" => "Field2", "type" => "string", "default" => "World"}
      ]

      content = %{}

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user_id,
        last_change_at: DateTime.utc_now()
      }

      version_attrs = %{
        ingest: ingest_attrs,
        content: content,
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user_id,
        last_change_at: DateTime.utc_now(),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, content_schema)

      assert {:ok, %{ingest_version: ingest_version}} = Workflow.create_ingest(creation_attrs)

      assert ingest_version.content["Field1"] == "Hello"
      assert ingest_version.content["Field2"] == "World"
    end

    test "with invalid content: invalid variable list", %{claims: %{user_id: user_id}} do
      domain_id = 1

      content_schema = [
        %{"name" => "Field1", "type" => "string", "cardinality" => "*"}
      ]

      content = %{"Field1" => "World"}

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user_id,
        last_change_at: DateTime.utc_now()
      }

      version_attrs = %{
        ingest: ingest_attrs,
        content: content,
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user_id,
        last_change_at: DateTime.utc_now(),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, content_schema)

      assert {:ok, %{ingest_version: ingest_version}} = Workflow.create_ingest(creation_attrs)

      assert ingest_version.content == version_attrs.content
      assert ingest_version.name == version_attrs.name
      assert ingest_version.description == version_attrs.description
      assert ingest_version.last_change_by == version_attrs.last_change_by
      assert ingest_version.current == true
      assert ingest_version.in_progress == true
      assert ingest_version.version == version_attrs.version
      assert ingest_version.ingest.type == ingest_attrs.type
      assert ingest_version.ingest.domain_id == ingest_attrs.domain_id
      assert ingest_version.ingest.last_change_by == ingest_attrs.last_change_by
    end

    test "with no content", %{claims: %{user_id: user_id}} do
      domain_id = 1

      content_schema = [
        %{"name" => "Field1", "type" => "variable_list"}
      ]

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user_id,
        last_change_at: DateTime.utc_now()
      }

      version_attrs = %{
        ingest: ingest_attrs,
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user_id,
        last_change_at: DateTime.utc_now(),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, content_schema)

      assert {:error, :ingest_version, %Ecto.Changeset{} = changeset, _} =
               Workflow.create_ingest(creation_attrs)

      assert_expected_validation(changeset, "content", :required)
    end

    test "with nil content", %{claims: %{user_id: user_id}} do
      domain_id = 1

      content_schema = [
        %{"name" => "Field1", "type" => "variable_list"}
      ]

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user_id,
        last_change_at: DateTime.utc_now()
      }

      version_attrs = %{
        ingest: ingest_attrs,
        content: nil,
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user_id,
        last_change_at: DateTime.utc_now(),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, content_schema)

      assert {:error, :ingest_version, %Ecto.Changeset{} = changeset, _} =
               Workflow.create_ingest(creation_attrs)

      assert_expected_validation(changeset, "content", :required)
    end

    test "with no content schema", %{claims: %{user_id: user_id}} do
      domain_id = 1

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user_id,
        last_change_at: DateTime.utc_now()
      }

      creation_attrs = %{
        ingest: ingest_attrs,
        content: %{},
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user_id,
        last_change_at: DateTime.utc_now(),
        version: 1
      }

      assert_raise RuntimeError, "Content Schema is not defined for Ingest", fn ->
        Workflow.create_ingest(creation_attrs)
      end
    end
  end

  describe "update_ingest_version/2" do
    test "with valid data updates the ingest_version", %{claims: %{user_id: user_id}} do
      ingest_version = insert(:ingest_version)

      ingest_attrs = %{
        last_change_by: 1000,
        last_change_at: DateTime.utc_now()
      }

      version_attrs = %{
        ingest: ingest_attrs,
        ingest_id: ingest_version.ingest.id,
        content: %{},
        name: "updated name",
        description: to_rich_text("updated description"),
        last_change_by: user_id,
        last_change_at: DateTime.utc_now(),
        version: 1
      }

      update_attrs = Map.put(version_attrs, :content_schema, [])

      assert {:ok, %IngestVersion{} = object} =
               Workflow.update_ingest_version(
                 ingest_version,
                 update_attrs
               )

      assert object.name == version_attrs.name
      assert object.description == version_attrs.description
      assert object.last_change_by == version_attrs.last_change_by
      assert object.current == true
      assert object.version == version_attrs.version
      assert object.in_progress == false

      assert object.ingest.id == ingest_version.ingest.id
      assert object.ingest.last_change_by == 1000
    end

    test "with valid content data updates the ingest", %{claims: %{user_id: user_id}} do
      content_schema = [
        %{"name" => "Field1", "type" => "string", "required" => true},
        %{"name" => "Field2", "type" => "string", "required" => true}
      ]

      content = %{
        "Field1" => "First field",
        "Field2" => "Second field"
      }

      ingest_version = insert(:ingest_version, last_change_by: user_id, content: content)

      update_content = %{
        "Field1" => "New first field"
      }

      ingest_attrs = %{
        last_change_by: 1000,
        last_change_at: DateTime.utc_now()
      }

      version_attrs = %{
        ingest: ingest_attrs,
        ingest_id: ingest_version.ingest.id,
        content: update_content,
        name: "updated name",
        description: to_rich_text("updated description"),
        last_change_by: user_id,
        last_change_at: DateTime.utc_now(),
        version: 1
      }

      update_attrs = Map.put(version_attrs, :content_schema, content_schema)

      assert {:ok, ingest_version} =
               Workflow.update_ingest_version(
                 ingest_version,
                 update_attrs
               )

      assert %IngestVersion{} = ingest_version
      assert ingest_version.content["Field1"] == "New first field"
      assert ingest_version.content["Field2"] == "Second field"
    end

    test "with invalid data returns error changeset" do
      ingest_version = insert(:ingest_version)

      version_attrs = %{
        ingest: nil,
        content: %{},
        name: nil,
        description: nil,
        last_change_by: nil,
        last_change_at: nil,
        version: nil
      }

      update_attrs = Map.put(version_attrs, :content_schema, [])

      assert {:error, :updated, %Ecto.Changeset{}, _} =
               Workflow.update_ingest_version(
                 ingest_version,
                 update_attrs
               )

      object = Ingests.get_current_version_by_ingest_id!(ingest_version.ingest.id)

      assert object == ingest_version
    end
  end

  describe "new_ingest_version/2" do
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
            ],
            "name" => ""
          }
        ]
      }
      template_with_identifier = CacheHelpers.insert_template(with_identifier)
      [template_with_identifier: template_with_identifier, identifier_name: identifier_name]
    end
    test "creates a new version and sets current to false on previous version", %{
      claims: claims
    } do
      ingest_version = insert(:ingest_version, status: "published")
      assert {:ok, res} = Workflow.new_ingest_version(ingest_version, claims)
      assert %{current: %{current: true}, previous: %{current: false}} = res
    end

    test "creates a new version and copies the identifier from the previous version one", %{
      claims: claims,
      template_with_identifier: template_with_identifier,
      identifier_name: identifier_name
    } do
      existing_identifier = "00000000-0000-0000-0000-000000000000"
      ingest = build(:ingest, %{type: template_with_identifier.name})
      ingest_version =
        insert(:ingest_version, %{status: "published", ingest: ingest, content: %{"identifier" => existing_identifier}})

      assert {:ok, res} = Workflow.new_ingest_version(ingest_version, claims)
      assert %{
        current: %{
          content: %{^identifier_name => ^existing_identifier}
        },
        previous: %{
          content: %{^identifier_name => ^existing_identifier}
        },
      } = res
    end

    test "publishes an event to the audit stream", %{claims: claims} do
      ingest_version = insert(:ingest_version, status: "published")
      assert {:ok, %{audit: event_id}} = Workflow.new_ingest_version(ingest_version, claims)
      assert {:ok, [%{id: ^event_id}]} = Stream.read(:redix, @stream, transform: true)
    end
  end

  describe "publish_ingest_version/2" do
    test "changes the status and audit fields" do
      %{last_change_at: ts} = ingest_version = insert(:ingest_version, status: "draft")

      %{user_id: user_id} = claims = build(:claims, user_id: 987)

      assert {:ok, %{published: published}} =
               Workflow.publish_ingest_version(ingest_version, claims)

      assert %{status: "published", last_change_by: ^user_id, last_change_at: last_change_at} =
               published

      assert DateTime.diff(last_change_at, ts, :microsecond) > 0
    end

    test "publishes an event to ingests:events", %{claims: claims} do
      %{ingest_id: ingest_id, id: id} = ingest_version = insert(:ingest_version)
      assert {:ok, %{event: event_id}} = Workflow.publish_ingest_version(ingest_version, claims)

      assert {:ok, [[^event_id, event_data]]} =
               Stream.range(:redix, "ingests:events", event_id, event_id, transform: false)

      assert event_data == ["event", "publish", "id", "#{ingest_id}", "version_id", "#{id}"]
    end

    test "publishes an event including domain_ids to the audit stream", %{claims: claims} do
      ingest_version = insert(:ingest_version, status: "draft")

      assert {:ok, %{audit: event_id}} = Workflow.publish_ingest_version(ingest_version, claims)

      assert {:ok, [%{id: ^event_id} = event]} = Stream.read(:redix, @stream, transform: true)
      assert %{payload: payload} = event
      assert %{"domain_ids" => _domain_ids} = Jason.decode!(payload)
    end
  end

  describe "reject_ingest_version/3" do
    test "rejects ingest", %{claims: claims} do
      reason = "Because I want to"
      ingest_version = insert(:ingest_version, status: "pending_approval")

      assert {:ok, %{rejected: ingest_version}} =
               Workflow.reject_ingest_version(ingest_version, reason, claims)

      assert %{status: "rejected", reject_reason: ^reason} = ingest_version
    end

    test "publishes an event to the audit stream", %{claims: claims} do
      reason = "Because I want to"
      ingest_version = insert(:ingest_version, status: "pending_approval")

      assert {:ok, %{audit: event_id}} =
               Workflow.reject_ingest_version(ingest_version, reason, claims)

      assert {:ok, [%{id: ^event_id}]} = Stream.read(:redix, @stream, transform: true)
    end
  end

  describe "submit_ingest_version/2" do
    test "updates the ingest" do
      %{user_id: user_id} = claims = build(:claims)
      ingest_version = insert(:ingest_version)

      assert {:ok, %{updated: ingest_version}} =
               Workflow.submit_ingest_version(ingest_version, claims)

      assert %{status: "pending_approval", last_change_by: ^user_id} = ingest_version
    end

    test "publishes an event including domain_ids to the audit stream", %{claims: claims} do
      ingest_version = insert(:ingest_version, status: "draft")

      assert {:ok, %{audit: event_id}} = Workflow.submit_ingest_version(ingest_version, claims)

      assert {:ok, [%{id: ^event_id} = event]} = Stream.read(:redix, @stream, transform: true)
      assert %{payload: payload} = event
      assert %{"domain_ids" => _domain_ids} = Jason.decode!(payload)
    end
  end

  defp to_rich_text(plain) do
    %{"document" => plain}
  end

  defp assert_expected_validation(changeset, field, expected_validation) do
    find_def = {:unknown, {"", [validation: :unknown]}}

    current_validation =
      changeset.errors
      |> Enum.find(find_def, fn {key, _value} ->
        key == String.to_atom(field)
      end)
      |> elem(1)
      |> elem(1)
      |> Keyword.get(:validation)

    assert current_validation == expected_validation
    changeset
  end
end
