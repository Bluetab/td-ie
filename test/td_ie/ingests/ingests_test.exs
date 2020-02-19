defmodule TdIe.IngestsTests do
  @moduledoc """
  Unitary tests for ingest module
  """
  use TdIe.DataCase

  alias TdIe.Accounts.User
  alias TdIe.Ingests
  alias TdIe.Repo
  alias TdIeWeb.ApiServices.MockTdAuthService

  setup_all do
    start_supervised(MockTdAuthService)
    :ok
  end

  defp to_rich_text(plain) do
    %{"document" => plain}
  end

  describe "ingests" do
    alias TdIe.Ingests.Ingest
    alias TdIe.Ingests.IngestVersion

    defp fixture do
      template_content = [
        %{
          "name" => "group",
          "fields" => [%{name: "fieldname", type: "string", required: false}]
        }
      ]

      template =
        Templates.create_template(%{
          id: 0,
          name: "onefield",
          content: template_content,
          label: "label",
          scope: "ie"
        })

      parent_domain_id = 1
      child_domain_id = 2
      insert(:ingest, type: template.name, domain_id: child_domain_id)
      insert(:ingest, type: template.name, domain_id: parent_domain_id)
    end

    test "list_all_ingests/0 return all ingests" do
      fixture()
      assert length(Ingests.list_all_ingests()) == 2
    end

    test "load_ingest/1 return the expected ingest" do
      ingest = fixture()
      assert ingest.id == Ingests.get_ingest!(ingest.id).id
    end

    test "get_current_version_by_ingest_id!/1 returns the ingest with given id" do
      user = build(:user)
      ingest_version = insert(:ingest_version, last_change_by: user.id)

      object = Ingests.get_current_version_by_ingest_id!(ingest_version.ingest.id)

      assert object |> ingest_version_preload() == ingest_version
    end

    test "get_currently_published_version!/1 returns the published ingest with given id" do
      user = build(:user)

      in_published =
        insert(
          :ingest_version,
          last_change_by: user.id,
          status: Ingest.status().published
        )

      assert {:ok, _} = Ingests.new_ingest_version(%User{id: 1234}, in_published)
      in_current = Ingests.get_currently_published_version!(in_published.ingest.id)

      assert in_current.id == in_published.id
    end

    test "get_currently_published_version!/1 returns the last when there are no published" do
      user = build(:user)

      inv_draft =
        insert(
          :ingest_version,
          last_change_by: user.id,
          status: Ingest.status().draft
        )

      inv_current = Ingests.get_currently_published_version!(inv_draft.ingest.id)

      assert inv_current.id == inv_draft.id
    end

    test "get_current_version_by_ingest_id!/1 returns the ingest" do
      ingest_version = insert(:ingest_version)
      ingest_id = ingest_version.ingest.id

      ingest_version = Ingests.get_current_version_by_ingest_id!(ingest_id)

      assert !is_nil(ingest_version)
      assert !is_nil(ingest_version.ingest)
    end

    test "create_ingest/1 with valid data creates a ingest" do
      user = build(:user)
      domain_id = 1

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      version_attrs = %{
        ingest: ingest_attrs,
        content: %{},
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, [])

      assert {:ok, %IngestVersion{} = object} = Ingests.create_ingest(creation_attrs)

      assert object.content == version_attrs.content
      assert object.name == version_attrs.name
      assert object.description == version_attrs.description
      assert object.last_change_by == version_attrs.last_change_by
      assert object.current == true
      assert object.version == version_attrs.version
      assert object.in_progress == false
      assert object.ingest.type == ingest_attrs.type
      assert object.ingest.domain_id == ingest_attrs.domain_id
      assert object.ingest.last_change_by == ingest_attrs.last_change_by
    end

    test "create_ingest/1 with invalid data returns error changeset" do
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

      assert {:error, %Ecto.Changeset{}} = Ingests.create_ingest(creation_attrs)
    end

    test "create_ingest/1 with content" do
      user = build(:user)
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
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      version_attrs = %{
        ingest: ingest_attrs,
        content: content,
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, content_schema)

      assert {:ok, %IngestVersion{} = object} = Ingests.create_ingest(creation_attrs)

      assert object.content == content
    end

    test "create_ingest/1 with invalid content: required" do
      user = build(:user)
      domain_id = 1

      content_schema = [
        %{"name" => "Field1", "type" => "string", "cardinality" => "1"},
        %{"name" => "Field2", "type" => "string", "cardinality" => "1"}
      ]

      content = %{}

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      version_attrs = %{
        ingest: ingest_attrs,
        content: content,
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, content_schema)

      assert {:ok, %IngestVersion{} = object} = Ingests.create_ingest(creation_attrs)

      assert object.content == version_attrs.content
      assert object.name == version_attrs.name
      assert object.description == version_attrs.description
      assert object.last_change_by == version_attrs.last_change_by
      assert object.current == true
      assert object.in_progress == true
      assert object.version == version_attrs.version
      assert object.ingest.type == ingest_attrs.type
      assert object.ingest.domain_id == ingest_attrs.domain_id
      assert object.ingest.last_change_by == ingest_attrs.last_change_by
    end

    test "create_ingest/1 with content: default values" do
      user = build(:user)
      domain_id = 1

      content_schema = [
        %{"name" => "Field1", "type" => "string", "default" => "Hello"},
        %{"name" => "Field2", "type" => "string", "default" => "World"}
      ]

      content = %{}

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      version_attrs = %{
        ingest: ingest_attrs,
        content: content,
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, content_schema)

      assert {:ok, %IngestVersion{} = ingest_version} = Ingests.create_ingest(creation_attrs)

      assert ingest_version.content["Field1"] == "Hello"
      assert ingest_version.content["Field2"] == "World"
    end

    test "create_ingest/1 with invalid content: invalid variable list" do
      user = build(:user)
      domain_id = 1

      content_schema = [
        %{"name" => "Field1", "type" => "string", "cardinality" => "*"}
      ]

      content = %{"Field1" => "World"}

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      version_attrs = %{
        ingest: ingest_attrs,
        content: content,
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, content_schema)

      assert {:ok, %IngestVersion{} = object} = Ingests.create_ingest(creation_attrs)

      assert object.content == version_attrs.content
      assert object.name == version_attrs.name
      assert object.description == version_attrs.description
      assert object.last_change_by == version_attrs.last_change_by
      assert object.current == true
      assert object.in_progress == true
      assert object.version == version_attrs.version
      assert object.ingest.type == ingest_attrs.type
      assert object.ingest.domain_id == ingest_attrs.domain_id
      assert object.ingest.last_change_by == ingest_attrs.last_change_by
    end

    test "create_ingest/1 with no content" do
      user = build(:user)
      domain_id = 1

      content_schema = [
        %{"name" => "Field1", "type" => "variable_list"}
      ]

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      version_attrs = %{
        ingest: ingest_attrs,
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, content_schema)

      assert {:error, %Ecto.Changeset{} = changeset} = Ingests.create_ingest(creation_attrs)

      assert_expected_validation(changeset, "content", :required)
    end

    test "create_ingest/1 with nil content" do
      user = build(:user)
      domain_id = 1

      content_schema = [
        %{"name" => "Field1", "type" => "variable_list"}
      ]

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      version_attrs = %{
        ingest: ingest_attrs,
        content: nil,
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second),
        version: 1
      }

      creation_attrs = Map.put(version_attrs, :content_schema, content_schema)

      assert {:error, %Ecto.Changeset{} = changeset} = Ingests.create_ingest(creation_attrs)

      assert_expected_validation(changeset, "content", :required)
    end

    test "create_ingest/1 with no content schema" do
      user = build(:user)
      domain_id = 1

      ingest_attrs = %{
        type: "some_type",
        domain_id: domain_id,
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      creation_attrs = %{
        ingest: ingest_attrs,
        content: %{},
        name: "some name",
        description: to_rich_text("some description"),
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second),
        version: 1
      }

      assert_raise RuntimeError, "Content Schema is not defined for Ingest", fn ->
        Ingests.create_ingest(creation_attrs)
      end
    end

    test "check_ingest_name_availability/2 check not available" do
      user = build(:user)
      name = random_name()
      ingest_version = insert(:ingest_version, name: name, last_change_by: user.id)
      type = ingest_version.ingest.type

      assert {:name_not_available} == Ingests.check_ingest_name_availability(type, name)
    end

    test "check_ingest_name_availability/2 check available" do
      user = build(:user)
      name = random_name()
      ingest_version = insert(:ingest_version, name: name, last_change_by: user.id)
      exclude_ingest_id = ingest_version.ingest.id
      type = ingest_version.ingest.type

      assert {:name_available} ==
               Ingests.check_ingest_name_availability(
                 type,
                 name,
                 exclude_ingest_id
               )
    end

    test "check_ingest_name_availability/3 check not available" do
      assert [%{name: name}, %{ingest: %{id: exclude_id, type: type}}] =
               1..10
               |> Enum.map(fn _ -> random_name() end)
               |> Enum.uniq()
               |> Enum.take(2)
               |> Enum.map(&insert(:ingest_version, name: &1))

      assert {:name_not_available} ==
               Ingests.check_ingest_name_availability(type, name, exclude_id)
    end

    test "count_published_ingests/2 check count" do
      user = build(:user)

      ingest_version =
        insert(
          :ingest_version,
          last_change_by: user.id,
          status: Ingest.status().published
        )

      type = ingest_version.ingest.type
      ids = [ingest_version.ingest.id]
      assert 1 == Ingests.count_published_ingests(type, ids)
    end

    test "update_ingest_version/2 with valid data updates the ingest_version" do
      user = build(:user)
      ingest_version = insert(:ingest_version)

      ingest_attrs = %{
        last_change_by: 1000,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      version_attrs = %{
        ingest: ingest_attrs,
        ingest_id: ingest_version.ingest.id,
        content: %{},
        name: "updated name",
        description: to_rich_text("updated description"),
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second),
        version: 1
      }

      update_attrs = Map.put(version_attrs, :content_schema, [])

      assert {:ok, %IngestVersion{} = object} =
               Ingests.update_ingest_version(
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

    test "update_ingest_version/2 with valid content data updates the ingest" do
      content_schema = [
        %{"name" => "Field1", "type" => "string", "required" => true},
        %{"name" => "Field2", "type" => "string", "required" => true}
      ]

      user = build(:user)

      content = %{
        "Field1" => "First field",
        "Field2" => "Second field"
      }

      ingest_version = insert(:ingest_version, last_change_by: user.id, content: content)

      update_content = %{
        "Field1" => "New first field"
      }

      ingest_attrs = %{
        last_change_by: 1000,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      version_attrs = %{
        ingest: ingest_attrs,
        ingest_id: ingest_version.ingest.id,
        content: update_content,
        name: "updated name",
        description: to_rich_text("updated description"),
        last_change_by: user.id,
        last_change_at: DateTime.utc_now() |> DateTime.truncate(:second),
        version: 1
      }

      update_attrs = Map.put(version_attrs, :content_schema, content_schema)

      assert {:ok, ingest_version} =
               Ingests.update_ingest_version(
                 ingest_version,
                 update_attrs
               )

      assert %IngestVersion{} = ingest_version
      assert ingest_version.content["Field1"] == "New first field"
      assert ingest_version.content["Field2"] == "Second field"
    end

    test "update_ingest_version/2 with invalid data returns error changeset" do
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

      assert {:error, %Ecto.Changeset{}} =
               Ingests.update_ingest_version(
                 ingest_version,
                 update_attrs
               )

      object = Ingests.get_current_version_by_ingest_id!(ingest_version.ingest.id)

      assert object |> ingest_version_preload() == ingest_version
    end

    test "new_ingest_version/2 creates a new version" do
      user = build(:user)

      ingest_version =
        insert(
          :ingest_version,
          last_change_by: user.id,
          status: Ingest.status().published
        )

      assert {:ok, %{current: new_version}} =
               Ingests.new_ingest_version(%User{id: 1234}, ingest_version)

      assert %IngestVersion{} = new_version

      assert Ingests.get_ingest_version!(ingest_version.id).current == false

      assert Ingests.get_ingest_version!(new_version.id).current == true
    end

    test "change_ingest/1 returns a ingest changeset" do
      user = build(:user)
      ingest = insert(:ingest, last_change_by: user.id)
      assert %Ecto.Changeset{} = Ingests.change_ingest(ingest)
    end
  end

  describe "ingest_versions" do
    alias TdIe.Ingests.Ingest
    alias TdIe.Ingests.IngestVersion

    test "list_all_ingest_versions/0 returns all ingest_versions" do
      ingest_version = insert(:ingest_version)
      ingest_versions = Ingests.list_all_ingest_versions()

      assert ingest_versions
             |> Enum.map(fn iv -> ingest_version_preload(iv) end) == [ingest_version]
    end

    test "find_ingest_versions/1 returns filtered ingest_versions" do
      published = Ingest.status().published
      draft = Ingest.status().draft
      domain_id = 1

      id = [create_version(domain_id, "one", draft).ingest.id]
      id = [create_version(domain_id, "two", published).ingest.id | id]
      id = [create_version(domain_id, "three", published).ingest.id | id]

      ingest_versions = Ingests.find_ingest_versions(%{id: id, status: [published]})

      assert 2 == length(ingest_versions)
    end

    defp create_version(domain_id, name, status) do
      ingest = insert(:ingest, domain_id: domain_id)

      insert(
        :ingest_version,
        ingest: ingest,
        name: name,
        status: status
      )
    end

    test "list_ingest_versions/1 returns all ingest_versions of a ingest_version" do
      ingest_version = insert(:ingest_version)
      ingest_id = ingest_version.ingest.id

      ingest_versions =
        Ingests.list_ingest_versions(ingest_id, [
          Ingest.status().draft
        ])

      assert ingest_versions
             |> Enum.map(fn i -> ingest_version_preload(i) end) == [ingest_version]
    end

    test "get_ingest_version!/1 returns the ingest_version with given id" do
      ingest_version = insert(:ingest_version)
      object = Ingests.get_ingest_version!(ingest_version.id)
      assert object |> ingest_version_preload() == ingest_version
    end

    test "update_ingest_version_status/2 with valid status data updates the ingest" do
      user = build(:user)
      ingest_version = insert(:ingest_version, last_change_by: user.id)
      attrs = %{status: Ingest.status().published}

      assert {:ok, ingest_version} =
               Ingests.update_ingest_version_status(
                 ingest_version,
                 attrs
               )

      assert ingest_version.status == Ingest.status().published
    end

    test "reject_ingest_version/2 rejects ingest" do
      user = build(:user)

      ingest_version =
        insert(
          :ingest_version,
          status: Ingest.status().pending_approval,
          last_change_by: user.id
        )

      attrs = %{reject_reason: "Because I want to"}

      assert {:ok, ingest_version} = Ingests.reject_ingest_version(ingest_version, attrs)

      assert ingest_version.status == Ingest.status().rejected
      assert ingest_version.reject_reason == attrs.reject_reason
    end

    test "change_ingest_version/1 returns a ingest_version changeset" do
      user = build(:user)
      ingest_version = insert(:ingest_version, last_change_by: user.id)

      assert %Ecto.Changeset{} = Ingests.change_ingest_version(ingest_version)
    end
  end

  defp ingest_version_preload(ingest_version) do
    ingest_version
    |> Repo.preload(:ingest)
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

  describe "ingest_executions" do
    alias TdIe.Ingests.IngestExecution

    @valid_attrs %{
      end_timestamp: ~N[2010-04-17 14:00:00.000000],
      start_timestamp: ~N[2010-04-17 14:00:00.000000],
      status: "some status"
    }
    @update_attrs %{
      end_timestamp: ~N[2011-05-18 15:01:01.000000],
      start_timestamp: ~N[2011-05-18 15:01:01.000000],
      status: "some updated status"
    }
    @invalid_attrs %{end_timestamp: nil, start_timestamp: nil, status: nil}

    def ingest_execution_fixture(attrs \\ %{}) do
      {:ok, ingest_execution} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Ingests.create_ingest_execution()

      ingest_execution
    end

    test "list_ingest_executions/0 returns all ingest_executions" do
      %{id: ingest_id} = insert(:ingest)
      ingest_execution = insert(:ingest_execution, ingest_id: ingest_id)
      assert Ingests.list_ingest_executions(ingest_id) == [ingest_execution]
    end

    test "get_ingest_execution!/1 returns the ingest_execution with given id" do
      ingest_execution = ingest_execution_fixture()
      assert Ingests.get_ingest_execution!(ingest_execution.id) == ingest_execution
    end

    test "create_ingest_execution/1 with valid data creates a ingest_execution" do
      assert {:ok, %IngestExecution{} = ingest_execution} =
               Ingests.create_ingest_execution(@valid_attrs)

      assert ingest_execution.end_timestamp == ~N[2010-04-17 14:00:00]
      assert ingest_execution.start_timestamp == ~N[2010-04-17 14:00:00]
      assert ingest_execution.status == "some status"
    end

    test "create_ingest_execution/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Ingests.create_ingest_execution(@invalid_attrs)
    end

    test "update_ingest_execution/2 with valid data updates the ingest_execution" do
      ingest_execution = ingest_execution_fixture()

      assert {:ok, ingest_execution} =
               Ingests.update_ingest_execution(ingest_execution, @update_attrs)

      assert %IngestExecution{} = ingest_execution
      assert ingest_execution.end_timestamp == ~N[2011-05-18 15:01:01]
      assert ingest_execution.start_timestamp == ~N[2011-05-18 15:01:01]
      assert ingest_execution.status == "some updated status"
    end

    test "update_ingest_execution/2 with invalid data returns error changeset" do
      ingest_execution = ingest_execution_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Ingests.update_ingest_execution(ingest_execution, @invalid_attrs)

      assert ingest_execution == Ingests.get_ingest_execution!(ingest_execution.id)
    end

    test "delete_ingest_execution/1 deletes the ingest_execution" do
      ingest_execution = ingest_execution_fixture()
      assert {:ok, %IngestExecution{}} = Ingests.delete_ingest_execution(ingest_execution)

      assert_raise Ecto.NoResultsError, fn ->
        Ingests.get_ingest_execution!(ingest_execution.id)
      end
    end

    test "change_ingest_execution/1 returns a ingest_execution changeset" do
      ingest_execution = ingest_execution_fixture()
      assert %Ecto.Changeset{} = Ingests.change_ingest_execution(ingest_execution)
    end
  end

  defp random_name do
    id = :rand.uniform(100_000_000)
    "Ingest #{id}"
  end
end
