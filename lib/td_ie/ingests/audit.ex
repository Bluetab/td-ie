defmodule TdIe.Ingests.Audit do
  @moduledoc """
  Manages the creation of audit events relating to ingests
  """

  import Ecto.Query
  import TdIe.Audit.AuditSupport, only: [publish: 5]

  alias Ecto.Changeset
  alias TdIe.Ingests.IngestVersion
  alias TdIe.Repo

  def ingests_created(ingest_ids) do
    audit_fields = [
      :content,
      :description,
      :in_progress,
      :last_change_at,
      :last_change_by,
      :name,
      :status,
      :version,
      :ingest_id,
      ingest: [:domain_id, :last_change_at, :last_change_by, :type]
    ]

    IngestVersion
    |> where([v], v.ingest_id in ^ingest_ids)
    |> where([v], v.version == 1)
    |> preload(:ingest)
    |> select([v], map(v, ^audit_fields))
    |> Repo.all()
    |> Enum.map(&Map.pop(&1, :ingest_id))
    |> Enum.map(&ingest_created/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> case do
      %{error: errors} -> {:error, errors}
      %{ok: event_ids} -> {:ok, event_ids}
    end
  end

  def ingest_created(_repo, %{ingest_version: ingest_version}) do
    ingest_created(ingest_version)
  end

  def ingest_created(%IngestVersion{ingest_id: ingest_id}) do
    ingests_created([ingest_id])
  end

  def ingest_created({id, %{last_change_by: user_id} = payload}) do
    publish("create_ingest_draft", "ingest", id, user_id, payload)
  end

  def ingest_updated(_repo, %{updated: updated}, changeset) do
    case updated do
      %{ingest_id: id, last_change_by: user_id} ->
        publish("update_ingest_draft", "ingest", id, user_id, changeset)
    end
  end

  def ingest_published(_repo, %{published: ingest_version}) do
    case ingest_version do
      %{ingest_id: id, last_change_by: user_id} ->
        payload = Map.take(ingest_version, [:id, :ingest_id, :version])
        publish("ingest_published", "ingest", id, user_id, payload)
    end
  end

  def ingest_rejected(_repo, %{rejected: ingest_version}) do
    case ingest_version do
      %{ingest_id: id, last_change_by: user_id} ->
        payload = Map.take(ingest_version, [:id, :ingest_id, :version])
        publish("ingest_rejected", "ingest", id, user_id, payload)
    end
  end

  def ingest_versioned(_repo, %{current: current}) do
    case current do
      %{ingest_id: id, last_change_by: user_id, version: version} ->
        payload = %{version: version}
        publish("new_ingest_draft", "ingest", id, user_id, payload)
    end
  end

  def ingest_deleted(
        _repo,
        %{ingest_version: ingest_version},
        user_id
      ) do
    case ingest_version do
      %{version: version, ingest_id: id} ->
        payload = %{version: version}
        publish("delete_ingest_draft", "ingest", id, user_id, payload)
    end
  end

  def status_updated(_repo, %{updated: ingest_version}, %Changeset{} = changeset) do
    changeset
    |> Changeset.fetch_change!(:status)
    |> do_status_updated(ingest_version)
  end

  defp do_status_updated("pending_approval", ingest_version) do
    case ingest_version do
      %{version: version, ingest_id: id, last_change_by: user_id} ->
        payload = %{version: version}
        publish("ingest_sent_for_approval", "ingest", id, user_id, payload)
    end
  end

  defp do_status_updated("deprecated", ingest_version) do
    case ingest_version do
      %{version: version, ingest_id: id, last_change_by: user_id} ->
        payload = %{version: version}
        publish("ingest_deprecated", "ingest", id, user_id, payload)
    end
  end

  defp do_status_updated("draft", ingest_version) do
    case ingest_version do
      %{version: version, ingest_id: id, last_change_by: user_id} ->
        payload = %{version: version}
        publish("ingest_rejection_canceled", "ingest", id, user_id, payload)
    end
  end
end
