defmodule TdIeWeb.IngestVersionView do
  @moduledoc """
  Ingest version view
  """
  use TdHypermedia, :view
  use TdIeWeb, :view

  alias TdCache.UserCache
  alias TdIeWeb.IngestVersionView
  alias TdIeWeb.LinkView

  def render("index.json", %{hypermedia: hypermedia}) do
    render_many_hypermedia(hypermedia, IngestVersionView, "ingest_version.json")
  end

  def render("index.json", %{ingest_versions: ingest_versions}) do
    %{
      data:
        render_many(
          ingest_versions,
          IngestVersionView,
          "ingest_version.json"
        )
    }
  end

  def render("show.json", %{ingest_version: ingest_version, hypermedia: hypermedia, links_hypermedia: links_hypermedia} = assigns) do
    %{"data" => links} = render_many_hypermedia(links_hypermedia, LinkView, "embedded.json")
    render_one_hypermedia(
      ingest_version,
      hypermedia,
      IngestVersionView,
      "ingest_version.json",
      assigns
      |> Map.drop([:hypermedia])
      |> Map.delete(:links_hypermedia)
      |> Map.put("_embedded", %{links: links})
    )
  end

  def render("show.json", %{ingest_version: ingest_version, hypermedia: hypermedia} = assigns) do
    render_one_hypermedia(
      ingest_version,
      hypermedia,
      IngestVersionView,
      "ingest_version.json",
      Map.drop(assigns, [:ingest_version, :hypermedia])
    )
  end

  def render("show.json", %{ingest_version: ingest_version} = assigns) do
    %{
      data:
        render_one(
          ingest_version,
          IngestVersionView,
          "ingest_version.json",
          Map.drop(assigns, [:ingest_version])
        )
    }
  end

  def render("list.json", %{hypermedia: hypermedia}) do
    render_many_hypermedia(hypermedia, IngestVersionView, "list_item.json")
  end

  def render("list.json", %{ingest_versions: ingest_versions}) do
    %{data: render_many(ingest_versions, IngestVersionView, "list_item.json")}
  end

  def render("list_item.json", %{ingest_version: ingest_version}) do
    view_fields = [
      "id",
      "name",
      "description",
      "domain",
      "status",
      "content",
      "last_change_by",
      "last_change_at",
      "inserted_at",
      "updated_at",
      "domain_parents",
      "in_progress",
      "execution_status",
      "last_execution"
    ]

    type = get_in(ingest_version, ["template", "name"])
    test_fields = ["ingest_id", "current", "version"]

    ingest_version
    |> Map.take(view_fields ++ test_fields)
    |> Map.put("type", type)
  end

  def render("ingest_version.json", %{ingest_version: ingest_version} = assigns) do
    {:ok, user} = UserCache.get(ingest_version.last_change_by)

    %{
      content: ingest_version.content,
      current: ingest_version.current,
      description: ingest_version.description,
      domain: Map.get(ingest_version, :domain),
      id: ingest_version.id,
      in_progress: ingest_version.in_progress,
      ingest_id: ingest_version.ingest.id,
      last_change_at: ingest_version.last_change_at,
      last_change_by: ingest_version.last_change_by,
      last_change_user: user,
      name: ingest_version.name,
      status: ingest_version.status,
      type: ingest_version.ingest.type,
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
    |> add_template(assigns)
    |> add_embedded_resources(assigns)
  end

  def render("versions.json", %{hypermedia: hypermedia}) do
    render_many_hypermedia(hypermedia, IngestVersionView, "version.json")
  end

  def render("version.json", %{ingest_version: ingest_version}) do
    %{
      id: ingest_version["id"],
      ingest_id: ingest_version["ingest_id"],
      type: ingest_version["template"]["name"],
      content: ingest_version["content"],
      name: ingest_version["name"],
      description: ingest_version["description"],
      last_change_by: Map.get(ingest_version["last_change_by"], "full_name", ""),
      last_change_at: ingest_version["last_change_at"],
      domain: ingest_version["domain"],
      status: ingest_version["status"],
      current: ingest_version["current"],
      version: ingest_version["version"]
    }
  end

  defp add_reject_reason(ingest, reject_reason, :rejected) do
    Map.put(ingest, :reject_reason, reject_reason)
  end

  defp add_reject_reason(ingest, _reject_reason, _status), do: ingest

  defp add_mod_comments(ingest, _mod_comments, 1), do: ingest

  defp add_mod_comments(ingest, mod_comments, _version) do
    Map.put(ingest, :mod_comments, mod_comments)
  end

  def add_template(ingest, assigns) do
    case Map.get(assigns, :template, nil) do
      nil ->
        ingest

      template ->
        template_view = Map.take(template, [:content, :label])
        Map.put(ingest, :template, template_view)
    end
  end
end
