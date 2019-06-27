defmodule TdIeWeb.IngestVersionView do
  @moduledoc """
  Ingest version view
  """
  use TdIeWeb, :view
  use TdIeWeb.Hypermedia, :view

  alias TdCache.IngestCache
  alias TdCache.UserCache
  alias TdIeWeb.IngestVersionView

  def render("index.json", %{
        ingest_versions: ingest_versions,
        hypermedia: hypermedia
      }) do
    render_many_hypermedia(
      ingest_versions,
      hypermedia,
      IngestVersionView,
      "ingest_version.json"
    )
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

  def render(
        "show.json",
        %{
          ingest_version: ingest_version,
          hypermedia: hypermedia
        } = assigns
      ) do
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

  def render("list.json", %{
        ingest_versions: ingest_versions,
        hypermedia: hypermedia
      }) do
    render_many_hypermedia(
      ingest_versions,
      hypermedia,
      IngestVersionView,
      "list_item.json"
    )
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
      "rule_count",
      "link_count",
      "content",
      "last_change_by",
      "last_change_at",
      "inserted_at",
      "updated_at",
      "domain_parents",
      "in_progress"
    ]

    type = get_in(ingest_version, ["template", "name"])
    test_fields = ["ingest_id", "current", "version"]

    ingest_version
    |> Map.take(view_fields ++ test_fields)
    |> Map.put("type", type)
  end

  def render(
        "ingest_version.json",
        %{
          ingest_version: ingest_version
        } = assigns
      ) do
    {:ok, user} = UserCache.get(ingest_version.last_change_by)

    %{
      id: ingest_version.id,
      ingest_id: ingest_version.ingest.id,
      parent_id: ingest_version.ingest.parent_id,
      type: ingest_version.ingest.type,
      content: ingest_version.content,
      related_to: ingest_version.related_to,
      name: ingest_version.name,
      description: ingest_version.description,
      last_change_by: ingest_version.last_change_by,
      last_change_at: ingest_version.last_change_at,
      domain: Map.get(ingest_version, :domain),
      status: ingest_version.status,
      current: ingest_version.current,
      version: ingest_version.version,
      in_progress: ingest_version.in_progress,
      last_change_user: user
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
    |> add_parent(ingest_version.ingest)
    |> add_children(ingest_version.ingest)
  end

  def render("versions.json", %{
        ingest_versions: ingest_versions,
        hypermedia: hypermedia
      }) do
    render_many_hypermedia(
      ingest_versions,
      hypermedia,
      IngestVersionView,
      "version.json"
    )
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

  def add_parent(ingest_version_map, ingest) do
    case Ecto.assoc_loaded?(ingest.parent) do
      true ->
        parent_map =
          case ingest.parent do
            nil ->
              %{}

            parent ->
              %{
                id: IngestCache.get_ingest_version_id(parent.id),
                name: IngestCache.get_name(parent.id)
              }
          end

        Map.put(ingest_version_map, :parent, parent_map)

      false ->
        ingest_version_map
    end
  end

  def add_children(ingest_version_map, ingest) do
    case Ecto.assoc_loaded?(ingest.children) do
      true ->
        children_map =
          ingest.children
          |> Enum.reduce([], fn child, acc ->
            child_map = %{
              id: IngestCache.get_ingest_version_id(child.id),
              name: IngestCache.get_name(child.id)
            }

            [child_map | acc]
          end)

        Map.put(ingest_version_map, :children, children_map)

      false ->
        ingest_version_map
    end
  end
end
