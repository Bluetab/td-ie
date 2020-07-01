defmodule TdIe.Ingests.Workflow do
  @moduledoc """
  The Ingests Workflow context.
  """
  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdCache.EventStream.Publisher
  alias TdDfLib.Validation
  alias TdIe.Cache.IngestLoader
  alias TdIe.Ingests
  alias TdIe.Ingests.Audit
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestVersion
  alias TdIe.Repo

  @doc """
  Creates a ingest.

  ## Examples

      iex> create_ingest(%{field: value})
      {:ok, %IngestVersion{}}

      iex> create_ingest(%{field: bad_value})
      {:error, :ingest_version, %Ecto.Changeset{}, %{}}

  """
  def create_ingest(%{} = params) do
    params
    |> attrs_keys_to_atoms()
    |> raise_error_if_no_content_schema()
    |> set_content_defaults()
    |> validate_new_ingest()
    |> validate_description()
    |> validate_ingest_content()
    |> insert_ingest()
    |> on_create()
  end

  defp on_create(res) do
    with {:ok, %{ingest_version: %{ingest_id: ingest_id}}} <- res do
      IngestLoader.refresh(ingest_id)
      res
    end
  end

  @doc """
  Creates a new ingest version.
  """
  def new_ingest_version(%IngestVersion{} = ingest_version, %{id: user_id}) do
    ingest = ingest_version.ingest

    ingest =
      ingest
      |> Map.put("last_change_by", user_id)
      |> Map.put("last_change_at", DateTime.utc_now())

    draft_attrs = Map.from_struct(ingest_version)

    draft_attrs =
      draft_attrs
      |> Map.put("ingest", ingest)
      |> Map.put("last_change_by", user_id)
      |> Map.put("last_change_at", DateTime.utc_now())
      |> Map.put("status", "draft")
      |> Map.put("version", ingest_version.version + 1)

    result =
      draft_attrs
      |> attrs_keys_to_atoms()
      |> validate_new_ingest()
      |> version_ingest(ingest_version)

    case result do
      {:ok, %{current: new_version}} ->
        ingest_id = new_version.ingest_id
        IngestLoader.refresh(ingest_id)
        result

      _ ->
        result
    end
  end

  @doc """
  Updates a ingest.

  ## Examples

      iex> update_ingest_version(ingest_version, %{field: new_value})
      {:ok, %IngestVersion{}}

      iex> update_ingest_version(ingest_version, %{field: bad_value})
      {:error, :updated, %Ecto.Changeset{}, %{}}

  """
  def update_ingest_version(%IngestVersion{} = ingest_version, attrs) do
    result =
      attrs
      |> attrs_keys_to_atoms()
      |> raise_error_if_no_content_schema()
      |> add_content_if_not_exist()
      |> merge_content_with_ingest(ingest_version)
      |> set_content_defaults()
      |> validate_ingest(ingest_version)
      |> validate_ingest_content()
      |> validate_description()
      |> update_ingest()

    case result do
      {:ok, _} ->
        updated_version = Ingests.get_ingest_version!(ingest_version.id)
        ingest_id = updated_version.ingest_id
        IngestLoader.refresh(ingest_id)
        {:ok, updated_version}

      _ ->
        result
    end
  end

  def deprecate_ingest_version(%IngestVersion{} = ingest_version, user) do
    update_ingest_version_status(ingest_version, "deprecated", user)
  end

  def submit_ingest_version(%IngestVersion{} = ingest_version, user) do
    update_ingest_version_status(ingest_version, "pending_approval", user)
  end

  def undo_rejected_ingest_version(%IngestVersion{} = ingest_version, user) do
    update_ingest_version_status(ingest_version, "draft", user)
  end

  def publish_ingest_version(%{ingest_id: ingest_id} = ingest_version, %{id: user_id} = _user) do
    query =
      IngestVersion
      |> where([v], v.ingest_id == ^ingest_id)
      |> where([v], v.status == "published")

    changeset = IngestVersion.status_changeset(ingest_version, "published", user_id)

    Multi.new()
    |> Multi.update_all(:versioned, query, set: [status: "versioned"])
    |> Multi.update(:published, changeset)
    |> Multi.run(:event, __MODULE__, :ingest_published, [])
    |> Multi.run(:audit, Audit, :ingest_published, [])
    |> Repo.transaction()
    |> refresh()
  end

  defp refresh(result) do
    with {:ok, %{published: %IngestVersion{ingest_id: ingest_id}}} <- result do
      IngestLoader.refresh(ingest_id)
      result
    end
  end

  def ingest_published(_repo, %{published: %{id: id, ingest_id: ingest_id}}) do
    %{event: "publish", id: ingest_id, version_id: id}
    |> Publisher.publish("ingests:events")
  end

  def ingest_published(_repo, _changes), do: {:error, :invalid}

  def reject_ingest_version(%IngestVersion{} = ingest_version, reason, %{id: user_id}) do
    params = %{reject_reason: reason}
    changeset = IngestVersion.reject_changeset(ingest_version, params, user_id)

    Multi.new()
    |> Multi.update(:rejected, changeset)
    |> Multi.run(:audit, Audit, :ingest_rejected, [])
    |> Repo.transaction()
    |> case do
      {:ok, %{rejected: %{ingest_id: id}}} = result ->
        IngestLoader.refresh(id)
        result

      error ->
        error
    end
  end

  defp update_ingest_version_status(%IngestVersion{} = ingest_version, status, %{id: user_id}) do
    changeset = IngestVersion.status_changeset(ingest_version, status, user_id)

    Multi.new()
    |> Multi.update(:updated, changeset)
    |> Multi.run(:audit, Audit, :status_updated, [changeset])
    |> Repo.transaction()
    |> case do
      {:ok, %{updated: updated}} = result ->
        ingest_id = updated.ingest_id
        IngestLoader.refresh(ingest_id)
        result

      error ->
        error
    end
  end

  defp insert_ingest(%{changeset: changeset}) do
    Multi.new()
    |> Multi.insert(:ingest_version, changeset)
    |> Multi.run(:audit, Audit, :ingest_created, [])
    |> Repo.transaction()
  end

  defp update_ingest(%{changeset: changeset}) do
    Multi.new()
    |> Multi.update(:updated, changeset)
    |> Multi.run(:audit, Audit, :ingest_updated, [changeset])
    |> Repo.transaction()
  end

  defp version_ingest(%{changeset: changeset}, ingest_version) do
    Multi.new()
    |> Multi.update(:previous, Changeset.change(ingest_version, current: false))
    |> Multi.insert(:current, changeset)
    |> Multi.run(:audit, Audit, :ingest_versioned, [])
    |> Repo.transaction()
  end

  defp validate_description(attrs) do
    if Map.has_key?(attrs, :in_progress) && !attrs.in_progress do
      do_validate_description(attrs)
    else
      attrs
    end
  end

  defp do_validate_description(attrs) do
    import Ecto.Changeset, only: [put_change: 3]

    if !attrs.description == %{} do
      attrs
      |> Map.put(:changeset, put_change(attrs.changeset, :in_progress, true))
      |> Map.put(:in_progress, true)
    else
      attrs
      |> Map.put(:changeset, put_change(attrs.changeset, :in_progress, false))
      |> Map.put(:in_progress, false)
    end
  end

  defp validate_ingest_content(attrs) do
    changeset = Map.get(attrs, :changeset)

    if changeset.valid? do
      do_validate_ingest_content(attrs)
    else
      attrs
    end
  end

  defp do_validate_ingest_content(attrs) do
    import Ecto.Changeset, only: [put_change: 3]

    content = Map.get(attrs, :content)
    content_schema = Map.get(attrs, :content_schema)
    changeset = Validation.build_changeset(content, content_schema)

    if changeset.valid? do
      attrs
      |> Map.put(:changeset, put_change(attrs.changeset, :in_progress, false))
      |> Map.put(:in_progress, false)
    else
      attrs
      |> Map.put(:changeset, put_change(attrs.changeset, :in_progress, true))
      |> Map.put(:in_progress, true)
    end
  end

  defp validate_ingest(attrs, %IngestVersion{} = ingest_version) do
    changeset = IngestVersion.update_changeset(ingest_version, attrs)
    Map.put(attrs, :changeset, changeset)
  end

  defp validate_new_ingest(attrs) do
    changeset = IngestVersion.create_changeset(%IngestVersion{}, attrs)
    Map.put(attrs, :changeset, changeset)
  end

  defp set_content_defaults(attrs) do
    content = Map.get(attrs, :content)
    content_schema = Map.get(attrs, :content_schema)
    new_content = set_default_values(content, content_schema)
    Map.put(attrs, :content, new_content)
  end

  defp set_default_values(content, [tails | head]) do
    content
    |> set_default_value(tails)
    |> set_default_values(head)
  end

  defp set_default_values(content, []), do: content

  defp set_default_value(content, %{"name" => name, "default" => default}) do
    case content[name] do
      nil ->
        content |> Map.put(name, default)

      _ ->
        content
    end
  end

  defp set_default_value(content, %{}), do: content

  defp merge_content_with_ingest(attrs, %IngestVersion{} = ingest_version) do
    content = Map.get(attrs, :content)
    ingest_content = Map.get(ingest_version, :content, %{})
    new_content = Map.merge(ingest_content, content)
    Map.put(attrs, :content, new_content)
  end

  defp add_content_if_not_exist(attrs) do
    if Map.has_key?(attrs, :content) do
      attrs
    else
      Map.put(attrs, :content, %{})
    end
  end

  defp raise_error_if_no_content_schema(attrs) do
    if not Map.has_key?(attrs, :content_schema) do
      raise "Content Schema is not defined for Ingest"
    end

    attrs
  end

  defp attrs_keys_to_atoms(key_values) do
    map = map_keys_to_atoms(key_values)

    case map.ingest do
      %Ingest{} -> map
      %{} = ingest -> Map.put(map, :ingest, map_keys_to_atoms(ingest))
      _ -> map
    end
  end

  defp map_keys_to_atoms(key_values) do
    Map.new(
      Enum.map(key_values, fn
        {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
        {key, value} when is_atom(key) -> {key, value}
      end)
    )
  end
end
