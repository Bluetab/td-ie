defmodule TdIe.Ingests do
  @moduledoc """
  The Ingests context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdCache.TaxonomyCache
  alias TdIe.Auth.Claims
  alias TdIe.Cache.IngestLoader
  alias TdIe.Ingests.Audit
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestExecution
  alias TdIe.Ingests.IngestVersion
  alias TdIe.Repo
  alias TdIe.Search.Indexer

  @doc """
  check ingest name availability
  """
  def check_ingest_name_availability(type, name, exclude_ingest_id \\ nil)

  def check_ingest_name_availability(type, name, _exclude_ingest_id)
      when is_nil(name) or is_nil(type),
      do: :ok

  def check_ingest_name_availability(type, name, exclude_ingest_id) do
    status = ["versioned", "deprecated"]

    Ingest
    |> join(:left, [i], _ in assoc(i, :versions))
    |> where([i, v], i.type == ^type and v.status not in ^status)
    |> include_name_where(name, exclude_ingest_id)
    |> select([i, v], count(i.id))
    |> Repo.one!()
    |> case do
      0 -> :ok
      _ -> {:error, :name_not_available}
    end
  end

  defp include_name_where(query, name, nil) do
    where(query, [_, v], v.name == ^name)
  end

  defp include_name_where(query, name, exclude_ingest_id) do
    where(
      query,
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
    Repo.one!(
      from(i in Ingest,
        where: i.id == ^ingest_id
      )
    )
  end

  @doc """
  count published business ingests
  ingest must be of indicated type
  ingest are resticted to indicated id list
  """
  def count_published_ingests(type, ids) do
    Ingest
    |> join(:left, [i], _ in assoc(i, :versions))
    |> where([i, v], i.type == ^type and i.id in ^ids and v.status == "published")
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
    version =
      IngestVersion
      |> where([v], v.ingest_id == ^ingest_id)
      |> where([v], v.status == "published")
      |> preload(:ingest)
      |> Repo.one()

    case version do
      nil -> get_current_version_by_ingest_id!(ingest_id)
      _ -> version
    end
  end

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
    |> preload(ingest: :executions)
    |> Repo.all()
  end

  @doc """
  Returns the list of ingest versions given a filter.

  ## Examples

      iex> list_all_ingest_versions(%{id: id})
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

  def with_domain(%IngestVersion{ingest: ingest} = ingest_version) do
    domain =
      ingest
      |> Map.get(:domain_id)
      |> get_domain()

    Map.put(ingest_version, :domain, domain)
  end

  def with_domain(%Ingest{domain_id: domain_id} = ingest) do
    domain = get_domain(domain_id)
    Map.put(ingest, :domain, domain)
  end

  def get_domain(nil), do: %{}

  def get_domain(domain_id) do
    TaxonomyCache.get_domain(domain_id)
  end

  @doc """
  Deletes a IngestVersion.

  ## Examples

      iex> delete_ingest_version(ingest_version, claims)
      {:ok, %IngestVersion{}}

      iex> delete_ingest_version(ingest_version, claims)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ingest_version(%IngestVersion{} = ingest_version, %Claims{user_id: user_id}) do
    if ingest_version.version == 1 do
      ingest = ingest_version.ingest
      ingest_id = ingest.id

      Multi.new()
      |> Multi.delete(:ingest_version, ingest_version)
      |> Multi.delete(:ingest, ingest)
      |> Multi.run(:audit, Audit, :ingest_deleted, [user_id])
      |> Repo.transaction()
      |> case do
        {:ok,
         %{
           ingest: %Ingest{},
           ingest_version: %IngestVersion{} = version
         }} ->
          IngestLoader.delete(ingest_id)
          Indexer.delete(ingest_version.id)
          {:ok, version}
      end
    else
      Multi.new()
      |> Multi.delete(:ingest_version, ingest_version)
      |> Multi.update(:current, IngestVersion.current_changeset(ingest_version))
      |> Multi.run(:audit, Audit, :ingest_deleted, [user_id])
      |> Repo.transaction()
      |> case do
        {:ok,
         %{
           ingest_version: %IngestVersion{} = deleted_version,
           current: %IngestVersion{} = current_version
         }} ->
          Indexer.delete(deleted_version.id)
          {:ok, current_version}
      end
    end
  end

  def get_ingest_by_name(name) do
    Ingest
    |> join(:left, [v], _ in assoc(v, :versions))
    |> where([i, v], i.id == v.ingest_id and ilike(v.name, ^"%#{name}%"))
    |> limit(1)
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

  @doc """
  Returns the list of ingest_executions.

  ## Examples

      iex> list_ingest_executions()
      [%IngestExecution{}, ...]

  """
  def list_ingest_executions(ingest_id) do
    IngestExecution
    |> where([v], v.ingest_id == ^ingest_id)
    |> Repo.all()
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
    |> case do
      {:ok, ingest_execution} ->
        refresh_ingest(ingest_execution)
        {:ok, ingest_execution}

      err ->
        err
    end
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
    |> case do
      {:ok, ingest_execution} ->
        refresh_ingest(ingest_execution)
        {:ok, ingest_execution}

      err ->
        err
    end
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
    ingest_execution
    |> Repo.delete()
    |> case do
      {:ok, %IngestExecution{}} ->
        refresh_ingest(ingest_execution)
        {:ok, %IngestExecution{}}

      err ->
        err
    end
  end

  def get_last_execution([]), do: %{}

  def get_last_execution(executions) do
    start_execution = last_execution(executions, :start_timestamp)
    end_execution = last_execution(executions, :end_timestamp)

    [end_execution, start_execution]
    |> Enum.filter(& &1)
    |> Enum.sort_by(&elem(&1, 0), {:desc, NaiveDateTime})
    |> case do
      [] ->
        Map.new()

      [head | _] ->
        execution = elem(head, 0)
        status = head |> elem(1) |> Map.get(:status)
        %{execution: execution, status: status}
    end
  end

  defp refresh_ingest(%IngestExecution{ingest_id: ingest_id}) do
    unless is_nil(ingest_id) do
      IngestLoader.refresh(ingest_id)
    end
  end

  defp last_execution(executions, key) do
    executions
    |> Enum.filter(&Map.get(&1, key))
    |> Enum.sort_by(&Map.get(&1, key), {:desc, NaiveDateTime})
    |> case do
      [] -> nil
      [head | _] -> {Map.get(head, key), head}
    end
  end
end
