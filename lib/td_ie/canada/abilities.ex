defmodule TdIe.Canada.Abilities do
  @moduledoc false
  alias TdIe.Accounts.User
  alias TdIe.Canada.IngestAbilities
  alias TdIe.Ingests.Ingest
  alias TdIe.Ingests.IngestVersion
  alias TdIe.Canada.LinkAbilities
  alias TdCache.Link

  defimpl Canada.Can, for: User do
    # administrator is superpowerful
    def can?(%User{is_admin: true}, _action, Ingest) do
      true
    end

    def can?(%User{is_admin: true}, _action, %Ingest{}) do
      true
    end

    def can?(%User{is_admin: true}, _action, %{resource_type: "domain"}) do
      true
    end

    def can?(%User{} = user, :create_ingest, %{resource_type: "domain"} = domain) do
      IngestAbilities.can?(user, :create_ingest, domain)
    end

    def can?(%User{} = user, :create, IngestVersion) do
      IngestAbilities.can?(user, :create_ingest)
    end

    def can?(%User{} = user, :create, %IngestVersion{} = _ingest_version) do
      IngestAbilities.can?(user, :create_ingest)
    end

    def can?(%User{} = user, :update, %IngestVersion{} = ingest_version) do
      IngestAbilities.can?(user, :update, ingest_version)
    end

    def can?(
          %User{} = user,
          :send_for_approval,
          %IngestVersion{} = ingest_version
        ) do
      IngestAbilities.can?(user, :send_for_approval, ingest_version)
    end

    def can?(%User{} = user, :reject, %IngestVersion{} = ingest_version) do
      IngestAbilities.can?(user, :reject, ingest_version)
    end

    def can?(
          %User{} = user,
          :undo_rejection,
          %IngestVersion{} = ingest_version
        ) do
      IngestAbilities.can?(user, :undo_rejection, ingest_version)
    end

    def can?(%User{} = user, :publish, %IngestVersion{} = ingest_version) do
      IngestAbilities.can?(user, :publish, ingest_version)
    end

    def can?(%User{} = user, :version, %IngestVersion{} = ingest_version) do
      IngestAbilities.can?(user, :version, ingest_version)
    end

    def can?(%User{} = user, :deprecate, %IngestVersion{} = ingest_version) do
      IngestAbilities.can?(user, :deprecate, ingest_version)
    end

    def can?(%User{} = user, :delete, %IngestVersion{} = ingest_version) do
      IngestAbilities.can?(user, :delete, ingest_version)
    end

    def can?(%User{} = user, :view_versions, %IngestVersion{} = ingest_version) do
      IngestAbilities.can?(user, :view_versions, ingest_version)
    end

    def can?(
          %User{} = user,
          :view_ingest,
          %IngestVersion{} = ingest_version
        ) do
      IngestAbilities.can?(user, :view_ingest, ingest_version)
    end

    def can?(%User{} = user, action, %Link{} = link) do
      LinkAbilities.can?(user, action, link)
    end

    def can?(%User{} = user, :create_link, %{ingest: ingest}) do
      LinkAbilities.can?(user, :create_link, ingest)
    end

    def can?(%User{} = user, action, %{hint: :link} = resource) do
      LinkAbilities.can?(user, action, resource)
    end

    def can?(%User{is_admin: true}, _action, %{}) do
      true
    end

    def can?(%User{}, _action, _domain), do: false
  end
end
