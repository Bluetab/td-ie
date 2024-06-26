defmodule TdIeWeb.IngestView do
  use TdHypermedia, :view
  use TdIeWeb, :view

  alias Ecto
  alias TdDfLib.Content
  alias TdIeWeb.IngestView

  def render("index.json", %{hypermedia: hypermedia}) do
    render_many_hypermedia(hypermedia, IngestView, "ingest.json")
  end

  def render("index.json", %{ingests: ingest_versions}) do
    %{data: render_many(ingest_versions, IngestView, "ingest.json")}
  end

  def render("show.json", %{ingest: ingest_versions, hypermedia: hypermedia}) do
    render_one_hypermedia(ingest_versions, hypermedia, IngestView, "ingest.json")
  end

  def render("show.json", %{ingest: ingest_versions}) do
    %{data: render_one(ingest_versions, IngestView, "ingest.json")}
  end

  def render("ingest.json", %{ingest: ingest_version}) do
    %{
      id: ingest_version.ingest.id,
      ingest_version_id: ingest_version.id,
      type: ingest_version.ingest.type,
      content: ingest_version.content,
      name: ingest_version.name,
      description: ingest_version.description,
      last_change_by: ingest_version.last_change_by,
      last_change_at: ingest_version.last_change_at,
      domain: Map.get(ingest_version, :domain),
      status: ingest_version.status,
      current: ingest_version.current,
      in_progress: ingest_version.in_progress,
      version: ingest_version.version
    }
    |> add_reject_reason(
      ingest_version.reject_reason,
      String.to_atom(ingest_version.status)
    )
    |> add_mod_comments(
      ingest_version.mod_comments,
      ingest_version.version
    )
    |> Content.legacy_content_support(:content)
  end

  def render("search.json", %{ingests: ingest_versions}) do
    %{data: render_many(ingest_versions, IngestView, "search_item.json")}
  end

  def render("search_item.json", %{ingest: ingest_version}) do
    %{id: ingest_version.ingest.id, name: ingest_version.name}
  end

  defp add_reject_reason(ingest, reject_reason, :rejected) do
    Map.put(ingest, :reject_reason, reject_reason)
  end

  defp add_reject_reason(ingest, _reject_reason, _status), do: ingest

  defp add_mod_comments(ingest, _mod_comments, 1), do: ingest

  defp add_mod_comments(ingest, mod_comments, _version) do
    Map.put(ingest, :mod_comments, mod_comments)
  end
end
