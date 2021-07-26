defmodule TdIe.IngestsTests do
  @moduledoc """
  Unitary tests for ingest module
  """
  use TdIe.DataCase

  alias TdIe.Ingests
  alias TdIe.Ingests.IngestExecution
  alias TdIe.Repo

  setup_all do
    [claims: build(:claims)]
  end

  describe "ingests" do
    test "list_all_ingests/0 return all ingests" do
      insert(:ingest, domain_id: 1)
      insert(:ingest, domain_id: 2)
      assert length(Ingests.list_all_ingests()) == 2
    end

    test "load_ingest/1 return the expected ingest" do
      %{id: id} = insert(:ingest)
      assert %{id: ^id} = Ingests.get_ingest!(id)
    end

    test "get_current_version_by_ingest_id!/1 returns the ingest with given id" do
      %{user_id: user_id} = build(:claims)
      %{ingest_id: ingest_id} = ingest_version = insert(:ingest_version, last_change_by: user_id)

      object = Ingests.get_current_version_by_ingest_id!(ingest_id)

      assert object == ingest_version
    end

    test "get_currently_published_version!/1 returns the published ingest with given id", %{
      claims: %{user_id: user_id}
    } do
      %{ingest: ingest} =
        in_published = insert(:ingest_version, last_change_by: user_id, status: "published")

      insert(:ingest_version, ingest: ingest, status: "draft")
      in_current = Ingests.get_currently_published_version!(in_published.ingest.id)
      assert in_current.id == in_published.id
    end

    test "get_currently_published_version!/1 returns the last when there are no published", %{
      claims: %{user_id: user_id}
    } do
      inv_draft = insert(:ingest_version, last_change_by: user_id, status: "draft")
      inv_current = Ingests.get_currently_published_version!(inv_draft.ingest.id)
      assert inv_current.id == inv_draft.id
    end

    test "get_current_version_by_ingest_id!/1 returns the ingest" do
      ingest_version = insert(:ingest_version)
      ingest_id = ingest_version.ingest.id

      ingest_version = Ingests.get_current_version_by_ingest_id!(ingest_id)

      refute is_nil(ingest_version)
      refute is_nil(ingest_version.ingest)
    end

    test "check_ingest_name_availability/2 check not available", %{claims: %{user_id: user_id}} do
      name = random_name()
      ingest_version = insert(:ingest_version, name: name, last_change_by: user_id)
      type = ingest_version.ingest.type

      assert {:error, :name_not_available} = Ingests.check_ingest_name_availability(type, name)
    end

    test "check_ingest_name_availability/2 check available", %{claims: %{user_id: user_id}} do
      name = random_name()
      ingest_version = insert(:ingest_version, name: name, last_change_by: user_id)
      exclude_ingest_id = ingest_version.ingest.id
      type = ingest_version.ingest.type

      assert Ingests.check_ingest_name_availability(type, name, exclude_ingest_id) == :ok
    end

    test "check_ingest_name_availability/3 check not available" do
      assert [%{name: name}, %{ingest: %{id: exclude_id, type: type}}] =
               1..10
               |> Enum.map(fn _ -> random_name() end)
               |> Enum.uniq()
               |> Enum.take(2)
               |> Enum.map(&insert(:ingest_version, name: &1))

      assert {:error, :name_not_available} =
               Ingests.check_ingest_name_availability(type, name, exclude_id)
    end

    test "count_published_ingests/2 check count", %{claims: %{user_id: user_id}} do
      ingest_version = insert(:ingest_version, last_change_by: user_id, status: "published")
      type = ingest_version.ingest.type
      ids = [ingest_version.ingest.id]
      assert 1 == Ingests.count_published_ingests(type, ids)
    end
  end

  describe "ingest_versions" do
    test "list_all_ingest_versions/0 returns all ingest_versions" do
      ingest_version = insert(:ingest_version)
      ingest_versions = Ingests.list_all_ingest_versions()

      assert Enum.map(ingest_versions, & &1.id) == [ingest_version.id]
    end

    test "find_ingest_versions/1 returns filtered ingest_versions" do
      domain_id = 1

      id = [create_version(domain_id, "one", "draft").ingest.id]
      id = [create_version(domain_id, "two", "published").ingest.id | id]
      id = [create_version(domain_id, "three", "published").ingest.id | id]

      ingest_versions = Ingests.find_ingest_versions(%{id: id, status: ["published"]})

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

      ingest_versions = Ingests.list_ingest_versions(ingest_id, ["draft"])

      assert ingest_versions
             |> Enum.map(fn i -> ingest_version_preload(i) end) == [ingest_version]
    end

    test "get_ingest_version!/1 returns the ingest_version with given id" do
      ingest_version = insert(:ingest_version)
      object = Ingests.get_ingest_version!(ingest_version.id)
      assert object |> ingest_version_preload() == ingest_version
    end
  end

  defp ingest_version_preload(ingest_version) do
    ingest_version
    |> Repo.preload(:ingest)
  end

  describe "ingest_executions" do
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

    test "get_last_execution/1 returns all ingest executions" do
      %{id: ingest_id} = insert(:ingest)
      init = DateTime.to_unix(DateTime.utc_now())
      start_timestamp = DateTime.from_unix!(init + 1)
      end_timestamp = DateTime.from_unix!(init + 2)

      ie =
        insert(:ingest_execution,
          ingest_id: ingest_id,
          start_timestamp: start_timestamp,
          end_timestamp: end_timestamp
        )

      start_timestamp = DateTime.from_unix!(init + 1)
      end_timestamp = DateTime.from_unix!(init + 3)

      ie_1 =
        insert(:ingest_execution,
          ingest_id: ingest_id,
          start_timestamp: start_timestamp,
          end_timestamp: end_timestamp
        )

      start_timestamp = DateTime.from_unix!(init + 4)

      ie_2 =
        insert(:ingest_execution,
          ingest_id: ingest_id,
          start_timestamp: start_timestamp,
          end_timestamp: nil
        )

      assert Ingests.get_last_execution([]) == %{}

      assert Ingests.get_last_execution([ie_2, ie, ie_1]) == %{
               execution: ie_2.start_timestamp,
               status: ie_2.status
             }
    end
  end

  defp random_name do
    id = System.unique_integer([:positive])
    "Ingest #{id}"
  end
end
