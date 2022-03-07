defmodule TdIeWeb.IngestVersionView do
  @moduledoc """
  Ingest version view
  """
  use TdHypermedia, :view
  use TdIeWeb, :view

  alias TdCache.UserCache
  alias TdDfLib.Format
  alias TdIeWeb.IngestVersionView
  alias TdIeWeb.LinkView

  def render("index.json", %{hypermedia: hypermedia}) do
    render_many_hypermedia(hypermedia, IngestVersionView, "ingest_version.json")
  end

  def render("index.json", %{ingest_versions: ingest_versions}) do
    %{data: render_many(ingest_versions, IngestVersionView, "ingest_version.json")}
  end

  def render(
        "show.json",
        %{
          ingest_version: ingest_version,
          hypermedia: hypermedia,
          links_hypermedia: links_hypermedia
        } = assigns
      ) do
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
    ingest_version
    |> Map.take([
      :content,
      :current,
      :description,
      :domain,
      :id,
      :in_progress,
      :ingest_id,
      :last_change_at,
      :last_change_by,
      :name,
      :status,
      :version
    ])
    |> Map.put(:type, type(ingest_version))
    |> Map.put(:last_change_user, last_change_user(ingest_version))
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
    |> add_cached_content(assigns)
  end

  def render("versions.json", %{hypermedia: hypermedia}) do
    render_many_hypermedia(hypermedia, IngestVersionView, "version.json")
  end

  def render("version.json", %{ingest_version: ingest_version}) do
    last_change_by = Map.get(ingest_version["last_change_by"], "full_name", "")

    ingest_version
    |> Map.take([
      "id",
      "ingest_id",
      "content",
      "name",
      "description",
      "last_change_at",
      "domain",
      "status",
      "current",
      "version"
    ])
    |> Map.put("type", type(ingest_version))
    |> Map.put("last_change_by", last_change_by)
  end

  defp type(%{ingest: %{type: type}}), do: type
  defp type(%{"template" => %{"name" => type}}), do: type
  defp type(_), do: nil

  defp last_change_user(%{last_change_by: user_id}) do
    case UserCache.get(user_id) do
      {:ok, %{} = user} -> Map.delete(user, :email)
      _ -> nil
    end
  end

  defp last_change_user(_), do: nil

  defp add_reject_reason(ingest, reject_reason, :rejected) do
    Map.put(ingest, :reject_reason, reject_reason)
  end

  defp add_reject_reason(ingest, _reject_reason, _status), do: ingest

  defp add_mod_comments(ingest, _mod_comments, 1), do: ingest

  defp add_mod_comments(ingest, mod_comments, _version) do
    Map.put(ingest, :mod_comments, mod_comments)
  end

  defp add_template(ingest, assigns) do
    case Map.get(assigns, :template, nil) do
      nil ->
        ingest

      template ->
        template_view = Map.take(template, [:content, :label])
        Map.put(ingest, :template, template_view)
    end
  end

  defp add_cached_content(ingest, assigns) do
    case Map.get(assigns, :template) do
      nil ->
        ingest

      template ->
        content =
          ingest
          |> Map.get(:content)
          |> Format.enrich_content_values(template)

        Map.put(ingest, :content, content)
    end
  end
end
