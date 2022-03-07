defmodule TdIe.Canada.Abilities do
  @moduledoc false
  alias TdCache.Link
  alias TdIe.Auth.Claims
  alias TdIe.Canada.IngestAbilities
  alias TdIe.Canada.LinkAbilities
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestVersion

  defimpl Canada.Can, for: Claims do
    # administrator is superpowerful
    def can?(%Claims{role: "admin"}, _action, Ingest) do
      true
    end

    def can?(%Claims{role: "admin"}, _action, %Ingest{}) do
      true
    end

    def can?(%Claims{role: "admin"}, _action, %{resource_type: "domain"}) do
      true
    end

    def can?(%Claims{} = claims, :create_ingest, %{resource_type: "domain"} = domain) do
      IngestAbilities.can?(claims, :create_ingest, domain)
    end

    def can?(%Claims{} = claims, :create, IngestVersion) do
      IngestAbilities.can?(claims, :create_ingest)
    end

    def can?(%Claims{} = claims, :create, %IngestVersion{} = _ingest_version) do
      IngestAbilities.can?(claims, :create_ingest)
    end

    def can?(%Claims{} = claims, :update, %IngestVersion{} = ingest_version) do
      IngestAbilities.can?(claims, :update, ingest_version)
    end

    def can?(
          %Claims{} = claims,
          :send_for_approval,
          %IngestVersion{} = ingest_version
        ) do
      IngestAbilities.can?(claims, :send_for_approval, ingest_version)
    end

    def can?(%Claims{} = claims, :reject, %IngestVersion{} = ingest_version) do
      IngestAbilities.can?(claims, :reject, ingest_version)
    end

    def can?(
          %Claims{} = claims,
          :undo_rejection,
          %IngestVersion{} = ingest_version
        ) do
      IngestAbilities.can?(claims, :undo_rejection, ingest_version)
    end

    def can?(%Claims{} = claims, :publish, %IngestVersion{} = ingest_version) do
      IngestAbilities.can?(claims, :publish, ingest_version)
    end

    def can?(%Claims{} = claims, :version, %IngestVersion{} = ingest_version) do
      IngestAbilities.can?(claims, :version, ingest_version)
    end

    def can?(%Claims{} = claims, :deprecate, %IngestVersion{} = ingest_version) do
      IngestAbilities.can?(claims, :deprecate, ingest_version)
    end

    def can?(%Claims{} = claims, :delete, %IngestVersion{} = ingest_version) do
      IngestAbilities.can?(claims, :delete, ingest_version)
    end

    def can?(
          %Claims{} = claims,
          :view_ingest,
          %IngestVersion{} = ingest_version
        ) do
      IngestAbilities.can?(claims, :view_ingest, ingest_version)
    end

    def can?(%Claims{} = claims, action, %Link{} = link) do
      LinkAbilities.can?(claims, action, link)
    end

    def can?(%Claims{} = claims, :create_link, %{ingest: ingest}) do
      LinkAbilities.can?(claims, :create_link, ingest)
    end

    def can?(%Claims{} = claims, action, %{hint: :link} = resource) do
      LinkAbilities.can?(claims, action, resource)
    end

    def can?(%Claims{role: "admin"}, _action, %{}) do
      true
    end

    def can?(%Claims{}, _action, _domain), do: false
  end
end
