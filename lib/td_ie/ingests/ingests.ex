defmodule TdIe.Ingests do
  @moduledoc """
  The Ingests context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Ecto.Multi
  alias TdDfLib.Validation
  alias TdIe.IngestLoader
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestVersion
  alias TdIe.Repo
  alias TdPerms.TaxonomyCache
  alias ValidationError

  @search_service Application.get_env(:td_ie, :elasticsearch)[:search_service]

  @changeset :changeset
  @content :content
  @content_schema :content_schema

  @doc """
    check ingest name availability
  """
  def check_ingest_name_availability(type, name, exclude_ingest_id \\ nil)

  def check_ingest_name_availability(type, name, _exclude_ingest_id)
      when is_nil(name) or is_nil(type),
      do: {:name_available}

  def check_ingest_name_availability(type, name, exclude_ingest_id) do
    status = [Ingest.status().versioned, Ingest.status().deprecated]

    count =
      Ingest
      |> join(:left, [i], _ in assoc(i, :versions))
      |> where([i, v], i.type == ^type and v.status not in ^status)
      |> include_name_where(name,  exclude_ingest_id)
      |> select([i, v], count(i.id))
      |> Repo.one!()

    if count == 0, do: {:name_available}, else: {:name_not_available}
  end

  defp include_name_where(query, name, nil) do
    query |> where([_, v], v.name == ^name)
  end

  defp include_name_where(query, name, exclude_ingest_id) do
    query
    |> where(
      [i, v],
      i.id != ^exclude_ingest_id and v.name == ^name
    )
  end

  @doc """
    list all ingests
    """
  def list_all_ingests do
    Ingest
      |> Repo.all()
  end

  def list_current_ingest_versions do
    IngestVersion
    |> where([v], v.current == true)
    |> preload(:ingest)
    |> Repo.all()
  end

  @doc """
    Fetch an exsisting ingest by its id
  """
  def get_ingest!(ingest_id) do
     Repo.one!(from(i in Ingest,
        where: i.id == ^ingest_id))
  end

  @doc """
    count published business ingests
    ingest must be of indicated type
    ingest are resticted to indicated id list
  """
  def count_published_ingests(type, ids) do
    published = Ingest.status().published

    Ingest
    |> join(:left, [i], _ in assoc(i, :versions))
    |> where([i, v], i.type == ^type and i.id in ^ids and v.status == ^published)
    |> select([i, _v], count(i.id))
    |> Repo.one!()
  end

  @doc """
  Returns children of domain id passed as argument
  """
  def get_domain_children_versions!(domain_id) do
    IngestVersion
    |> join(:left, [v], _ in assoc(v, :ingest))
    |> preload([_, i], ingest: i)
    |> where([_, i], i.domain_id == ^domain_id)
    |> Repo.all()
  end

  @doc """
  Gets a single ingest.

  Raises `Ecto.NoResultsError` if the ingest does not exist.

  ## Examples

      iex> get_current_version_by_ingest_id!(123)
      %Ingest{}

      iex> get_current_version_by_ingest_id!(456)
      ** (Ecto.NoResultsError)

  """
  def get_current_version_by_ingest_id!(ingest_id) do
    IngestVersion
    |> where([v], v.ingest_id == ^ingest_id)
    |> order_by(desc: :version)
    |> limit(1)
    |> preload(:ingest)
    |> Repo.one!()
  end

  def get_current_version_by_ingest_id!(ingest_id, %{current: current}) do
    IngestVersion
    |> where([v], v.ingest_id == ^ingest_id)
    |> where([v], v.current == ^current)
    |> order_by(desc: :version)
    |> limit(1)
    |> preload(:ingest)
    |> Repo.one!()
  end

  @doc """
  Gets a single ingest searching for the published version instead of the latest.

  Raises `Ecto.NoResultsError` if the Ingest does not exist.

  ## Examples

      iex> get_currently_published_version!(123)
      %IngestVersion{}

      iex> get_currently_published_version!(456)
      ** (Ecto.NoResultsError)

  """
  def get_currently_published_version!(ingest_id) do
    published = Ingest.status().published

    version =
    IngestVersion
    |> where([v], v.ingest_id == ^ingest_id)
    |> where([v], v.status == ^published)
    |> preload(:ingest)
    |> Repo.one()

    case version do
      nil -> get_current_version_by_ingest_id!(ingest_id)
      _ -> version
    end
  end

  @doc """
  Creates a ingest.

  ## Examples

      iex> create_ingest(%{field: value})
      {:ok, %IngestVersion{}}

      iex> create_ingest(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ingest(attrs \\ %{}) do
    result =
      attrs
      |> attrs_keys_to_atoms
      |> raise_error_if_no_content_schema
      |> set_content_defaults
      |> validate_new_ingest
      |> validate_description
      |> validate_ingest_content
      |> insert_ingest

    case result do
      {:ok, ingest_version} ->
        new_version = get_ingest_version!(ingest_version.id)
        ingest_id = new_version.ingest_id
        IngestLoader.refresh(ingest_id)
        index_ingest_versions(ingest_id)
        {:ok, new_version}

      _ ->
        result
    end
  end

  @doc """
  Creates a new ingest version.

  """
  def new_ingest_version(user, %IngestVersion{} = ingest_version) do
    ingest = ingest_version.ingest

    ingest =
      ingest
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now())

    draft_attrs = Map.from_struct(ingest_version)

    draft_attrs =
      draft_attrs
      |> Map.put("ingest", ingest)
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now())
      |> Map.put("status", Ingest.status().draft)
      |> Map.put("version", ingest_version.version + 1)

    result =
      draft_attrs
      |> attrs_keys_to_atoms
      |> validate_new_ingest
      |> version_ingest(ingest_version)

    case result do
      {:ok, %{current: new_version}} ->
        ingest_id = new_version.ingest_id
        IngestLoader.refresh(ingest_id)
        index_ingest_versions(ingest_id)
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
      {:error, %Ecto.Changeset{}}

  """
  def update_ingest_version(%IngestVersion{} = ingest_version, attrs) do
    result =
      attrs
      |> attrs_keys_to_atoms
      |> raise_error_if_no_content_schema
      |> add_content_if_not_exist
      |> merge_content_with_ingest(ingest_version)
      |> set_content_defaults
      |> validate_ingest(ingest_version)
      |> validate_ingest_content
      |> validate_description
      |> update_ingest

    case result do
      {:ok, _} ->
        updated_version = get_ingest_version!(ingest_version.id)
        ingest_id = updated_version.ingest_id
        IngestLoader.refresh(ingest_id)
        index_ingest_versions(ingest_id)
        {:ok, updated_version}

      _ ->
        result
    end
  end

  def update_ingest_version_status(
        %IngestVersion{} = ingest_version,
        attrs
      ) do
    result =
      ingest_version
      |> IngestVersion.update_status_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_version} ->
        ingest_id = updated_version.ingest_id
        IngestLoader.refresh(ingest_id)
        index_ingest_versions(ingest_id)
        result

      _ ->
        result
    end
  end

  def publish_ingest_version(ingest_version) do
    status_published = Ingest.status().published
    attrs = %{status: status_published}

    ingest_id = ingest_version.ingest.id

    query =
      from(
        c in IngestVersion,
        where: c.ingest_id == ^ingest_id and c.status == ^status_published
      )

    result =
      Multi.new()
      |> Multi.update_all(:versioned, query, set: [status: Ingest.status().versioned])
      |> Multi.update(
        :published,
        IngestVersion.update_status_changeset(ingest_version, attrs)
      )
      |> Repo.transaction()

    case result do
      {:ok, %{published: %IngestVersion{ingest_id: ingest_id}}} ->
        IngestLoader.refresh(ingest_id)
        index_ingest_versions(ingest_id)
        result

      _ ->
        result
    end
  end

  def index_ingest_versions(ingest_id) do
    ingest_id
    |> list_ingest_versions(nil)
    |> Enum.each(&@search_service.put_search/1)
  end

  def reject_ingest_version(%IngestVersion{} = ingest_version, attrs) do
    result =
      ingest_version
      |> IngestVersion.reject_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_version} ->
        ingest_id = updated_version.ingest_id
        IngestLoader.refresh(ingest_id)
        index_ingest_versions(ingest_id)
        result

      _ ->
        result
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ingest changes.

  ## Examples

      iex> change_ingest(ingest)
      %Ecto.Changeset{source: %Ingest{}}

  """
  def change_ingest(%Ingest{} = ingest) do
    Ingest.changeset(ingest, %{})
  end

  alias TdIe.Ingests.IngestVersion

  @doc """
  Returns the list of ingest_versions.

  ## Examples

      iex> list_all_ingest_versions(filter)
      [%IngestVersion{}, ...]

  """
  def list_all_ingest_versions do
    IngestVersion
    |> join(:left, [v], _ in assoc(v, :ingest))
    |> preload([_, i], ingest: i)
    |> order_by(asc: :version)
    |> Repo.all()
  end

  @doc """
  Returns the list of ingest_versions.

  ## Examples

      iex> list_all_ingest_versions()
      [%IngestVersion{}, ...]

  """
  def find_ingest_versions(filter) do
    query =
      IngestVersion
      |> join(:left, [v], _ in assoc(v, :ingest))
      |> preload([_, i], ingest: i)
      |> order_by(asc: :version)

    query =
      case Map.has_key?(filter, :id) && length(filter.id) > 0 do
        true ->
          id = Map.get(filter, :id)
          query |> where([_v, i], i.id in ^id)

        _ ->
          query
      end

    query =
      case Map.has_key?(filter, :status) && length(filter.status) > 0 do
        true ->
          status = Map.get(filter, :status)
          query |> where([v, _i], v.status in ^status)

        _ ->
          query
      end

    query |> Repo.all()
  end

  @doc """
  Returns the list of ingest_versions of a
  ingest

  ## Examples

      iex> list_ingest_versions(ingest_id)
      [%IngestVersion{}, ...]

  """
  def list_ingest_versions(ingest_id, status) do
    IngestVersion
    |> join(:left, [v], _ in assoc(v, :ingest))
    |> preload([_, i], ingest: i)
    |> where([_, i], i.id == ^ingest_id)
    |> include_status_in_where(status)
    |> order_by(desc: :version)
    |> Repo.all()
  end

  def list_all_ingest_with_status(status) do
    IngestVersion
    |> join(:left, [v], _ in assoc(v, :ingest))
    |> preload([_, i], ingest: i)
    |> include_status_in_where(status)
    |> order_by(asc: :version)
    |> Repo.all()
  end

  defp include_status_in_where(query, nil), do: query

  defp include_status_in_where(query, status) do
    query |> where([v, _], v.status in ^status)
  end

  @doc """
  Gets a single ingest_version.

  Raises `Ecto.NoResultsError` if the ingest version does not exist.

  ## Examples

      iex> get_ingest_version!(123)
      %IngestVersion{}

      iex> get_ingest_version!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ingest_version!(id) do
    IngestVersion
    |> join(:left, [v], _ in assoc(v, :ingest))
    |> preload([_, i], ingest: i)
    |> where([v, _], v.id == ^id)
    |> Repo.one!()
  end

  def retrieve_parent(%IngestVersion{ingest: ingest} = ingest_version, target_key) do
    parent_domain =
      ingest
        |> Map.get(:domain_id)
        |> retrieve_domain()

    ingest_version |> Map.put(target_key, parent_domain)
  end

  def retrieve_parent(%Ingest{domain_id: domain_id} = ingest, target_key) do
    parent_domain =
      domain_id
        |> retrieve_domain()

    ingest |> Map.put(target_key, parent_domain)
  end

  def retrieve_domain(nil), do: %{}

  def retrieve_domain(domain_id) do
    domain_name = TaxonomyCache.get_name(domain_id)
    return_domain_value(domain_id, domain_name)
  end

  def return_domain_value(_domain_id, nil), do: %{}

  def return_domain_value(domain_id, domain_name) do
    Map.new()
    |> Map.put(:id, domain_id)
    |> Map.put(:name, domain_name)
  end

  @doc """
  Deletes a IngestVersion.

  ## Examples

      iex> delete_ingest_version(ingest_version)
      {:ok, %IngestVersion{}}

      iex> delete_ingest_version(ingest_version)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ingest_version(%IngestVersion{} = ingest_version) do
    if ingest_version.version == 1 do
      ingest = ingest_version.ingest
      ingest_id = ingest.id
      Multi.new()
      |> Multi.update_all(:detatch_children,
        (from child in Ingest, where: child.parent_id == ^ingest_id),
        set: [parent_id: nil])
      |> Multi.delete(:ingest_version, ingest_version)
      |> Multi.delete(:ingest, ingest)
      |> Repo.transaction()
      |> case do
        {:ok,
         %{
           detatch_children: {_, nil},
           ingest: %Ingest{},
           ingest_version: %IngestVersion{} = version
         }} ->
          IngestLoader.delete(ingest_id)
          @search_service.delete_search(ingest_version)
          {:ok, version}
      end
    else
      Multi.new()
      |> Multi.delete(:ingest_version, ingest_version)
      |> Multi.update(
        :current,
        IngestVersion.current_changeset(ingest_version)
      )
      |> Repo.transaction()
      |> case do
        {:ok,
         %{
           ingest_version: %IngestVersion{} = deleted_version,
           current: %IngestVersion{} = current_version
         }} ->
          @search_service.delete_search(deleted_version)
          {:ok, current_version}
      end
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ingest_version changes.

  ## Examples

      iex> change_ingest_version(ingest_version)
      %Ecto.Changeset{source: %IngestVersion{}}

  """
  def change_ingest_version(%IngestVersion{} = ingest_version) do
    IngestVersion.changeset(ingest_version, %{})
  end

  defp map_keys_to_atoms(key_values) do
    Map.new(
      Enum.map(key_values, fn
        {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
        {key, value} when is_atom(key) -> {key, value}
      end)
    )
  end

  defp attrs_keys_to_atoms(key_values) do
    map = map_keys_to_atoms(key_values)
    case map.ingest do
      %Ingest{} -> map
      %{} = ingest -> Map.put(map, :ingest, map_keys_to_atoms(ingest))
      _ -> map
    end
  end

  defp raise_error_if_no_content_schema(attrs) do
    if not Map.has_key?(attrs, @content_schema) do
      raise "Content Schema is not defined for Ingest"
    end

    attrs
  end

  defp add_content_if_not_exist(attrs) do
    if not Map.has_key?(attrs, @content) do
      Map.put(attrs, @content, %{})
    else
      attrs
    end
  end

  defp validate_new_ingest(attrs) do
    changeset = IngestVersion.create_changeset(%IngestVersion{}, attrs)
    Map.put(attrs, @changeset, changeset)
  end

  defp validate_ingest(attrs, %IngestVersion{} = ingest_version) do
    changeset = IngestVersion.update_changeset(ingest_version, attrs)
    Map.put(attrs, @changeset, changeset)
  end

  defp merge_content_with_ingest(attrs, %IngestVersion{} = ingest_version) do
    content = Map.get(attrs, @content)
    ingest_content = Map.get(ingest_version, :content, %{})
    new_content = Map.merge(ingest_content, content)
    Map.put(attrs, @content, new_content)
  end

  defp set_content_defaults(attrs) do
    content = Map.get(attrs, @content)
    content_schema = Map.get(attrs, @content_schema)
    new_content = set_default_values(content, content_schema)
    Map.put(attrs, @content, new_content)
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

  defp validate_ingest_content(attrs) do
    changeset = Map.get(attrs, @changeset)

    if changeset.valid? do
      do_validate_ingest_content(attrs)
    else
      attrs
    end
  end

  defp do_validate_ingest_content(attrs) do
    content = Map.get(attrs, @content)
    content_schema = Map.get(attrs, @content_schema)
    changeset = Validation.build_changeset(content, content_schema)
    if not changeset.valid? do
      attrs
      |> Map.put(@changeset, put_change(attrs.changeset, :in_progress, true))
      |> Map.put(:in_progress, true)
    else
      attrs
      |> Map.put(@changeset, put_change(attrs.changeset, :in_progress, false))
      |> Map.put(:in_progress, false)
    end
  end

  defp validate_description(attrs) do
    if Map.has_key?(attrs, :in_progress) && !attrs.in_progress do
      do_validate_description(attrs)
    else
      attrs
    end
  end

  defp do_validate_description(attrs) do
    if !attrs.description == %{} do
      attrs
      |> Map.put(@changeset, put_change(attrs.changeset, :in_progress, true))
      |> Map.put(:in_progress, true)
    else
      attrs
      |> Map.put(@changeset, put_change(attrs.changeset, :in_progress, false))
      |> Map.put(:in_progress, false)
    end
  end

  defp update_ingest(attrs) do
    changeset = Map.get(attrs, @changeset)

    if changeset.valid? do
      Repo.update(changeset)
    else
      {:error, changeset}
    end
  end

  defp insert_ingest(attrs) do
    changeset = Map.get(attrs, @changeset)

    if changeset.valid? do
      Repo.insert(changeset)
    else
      {:error, changeset}
    end
  end

  defp version_ingest(attrs, ingest_version) do
    changeset = Map.get(attrs, @changeset)

    if changeset.valid? do
      Multi.new()
      |> Multi.update(
        :not_current,
        IngestVersion.not_anymore_current_changeset(ingest_version)
      )
      |> Multi.insert(:current, changeset)
      |> Repo.transaction()
    else
      {:error, %{current: changeset}}
    end
  end

  def get_ingest_by_name(name) do
    # Repo.all from r in IngestVersion, where:
    IngestVersion
    |> join(:left, [v], _ in assoc(v, :ingest))
    |> where([v], ilike(v.name, ^"%#{name}%"))
    |> preload([_, i], ingest: i)
    |> order_by(asc: :version)
    |> Repo.all()
  end

  def get_ingest_by_term(term) do
    IngestVersion
    |> join(:left, [v], _ in assoc(v, :ingest))
    |> where([v], ilike(v.name, ^"%#{term}%") or ilike(v.description, ^"%#{term}%"))
    |> preload([_, i], ingest: i)
    |> order_by(asc: :version)
    |> Repo.all()
  end

  def check_valid_related_to(_type, []), do: {:valid_related_to}

  def check_valid_related_to(type, ids) do
    input_count = length(ids)
    actual_count = count_published_ingests(type, ids)
    if input_count == actual_count, do: {:valid_related_to}, else: {:not_valid_related_to}
  end

  alias TdIe.Ingests.IngestExecution

  @doc """
  Returns the list of ingest_executions.

  ## Examples

      iex> list_ingest_executions()
      [%IngestExecution{}, ...]

  """
  def list_ingest_executions(ingest_id) do
    IngestExecution
    |> where([v], v.ingest_id == ^ingest_id)
    |> Repo.all
  end

  @doc """
  Gets a single ingest_execution.

  Raises `Ecto.NoResultsError` if the Ingest execution does not exist.

  ## Examples

      iex> get_ingest_execution!(123)
      %IngestExecution{}

      iex> get_ingest_execution!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ingest_execution!(id), do: Repo.get!(IngestExecution, id)

  @doc """
  Creates a ingest_execution.

  ## Examples

      iex> create_ingest_execution(%{field: value})
      {:ok, %IngestExecution{}}

      iex> create_ingest_execution(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ingest_execution(attrs \\ %{}) do
    %IngestExecution{}
    |> IngestExecution.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a ingest_execution.

  ## Examples

      iex> update_ingest_execution(ingest_execution, %{field: new_value})
      {:ok, %IngestExecution{}}

      iex> update_ingest_execution(ingest_execution, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ingest_execution(%IngestExecution{} = ingest_execution, attrs) do
    ingest_execution
    |> IngestExecution.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a IngestExecution.

  ## Examples

      iex> delete_ingest_execution(ingest_execution)
      {:ok, %IngestExecution{}}

      iex> delete_ingest_execution(ingest_execution)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ingest_execution(%IngestExecution{} = ingest_execution) do
    Repo.delete(ingest_execution)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ingest_execution changes.

  ## Examples

      iex> change_ingest_execution(ingest_execution)
      %Ecto.Changeset{source: %IngestExecution{}}

  """
  def change_ingest_execution(%IngestExecution{} = ingest_execution) do
    IngestExecution.changeset(ingest_execution, %{})
  end
end
