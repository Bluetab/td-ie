defmodule TdIe.Audit.AuditSupport do
  @moduledoc """
  Support module for publishing audit events.
  """

  alias Ecto.Changeset
  alias TdCache.Audit
  alias TdDfLib.{MapDiff, Masks}

  def publish(event, resource_type, resource_id, user_id, payload \\ %{})

  def publish(event, resource_type, resource_id, user_id, %Changeset{changes: changes, data: data}) do
    if map_size(changes) == 0 do
      {:ok, :unchanged}
    else
      Audit.publish(
        event: event,
        resource_type: resource_type,
        resource_id: resource_id,
        user_id: user_id,
        payload: payload(changes, data)
      )
    end
  end

  def publish(event, resource_type, resource_id, user_id, payload) do
    Audit.publish(
      event: event,
      resource_type: resource_type,
      resource_id: resource_id,
      user_id: user_id,
      payload: payload
    )
  end

  defp payload(%{last_change_at: _} = changes, data) do
    changes
    |> Map.drop([:last_change_at, :last_change_by])
    |> payload(data)
  end

  defp payload(%{ingest: %Changeset{changes: ingest_changes}} = changes, data) do
    ingest_changes = Map.drop(ingest_changes, [:last_change_by, :last_change_at])

    changes
    |> Map.delete(:ingest)
    |> Map.merge(ingest_changes)
    |> payload(data)
  end

  defp payload(%{content: new_content} = changes, %{content: old_content} = _data)
       when is_map(new_content) or is_map(old_content) do
    diff = MapDiff.diff(old_content, new_content, mask: &Masks.mask/1)

    changes
    |> Map.delete(:content)
    |> Map.put(:content, diff)
  end

  defp payload(changes, _data), do: changes
end
