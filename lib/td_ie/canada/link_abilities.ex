defmodule TdIe.Canada.LinkAbilities do
  @moduledoc """
  Canada permissions model for Ingest Link resources
  """
  alias TdCache.Link
  alias TdIe.Accounts.User
  alias TdIe.Ingests
  alias TdIe.Permissions

  require Logger

  def can?(%User{is_admin: true}, :create_link, _resource), do: true

  def can?(%User{is_admin: true}, _action, %Link{}), do: true

  def can?(%User{is_admin: true}, _action, %{hint: :link}), do: true

  def can?(%User{} = user, :delete, %Link{source: "ingest:" <> ingest_id}) do
    with %{domain_id: domain_id} <-
      Ingests.get_ingest!(String.to_integer(ingest_id)) do
      Permissions.authorized?(user, :manage_ingest_relations, domain_id)
    else
      error ->
        Logger.error("In LinkAbilities.can?/3 :delete Link... #{inspect(error)}")
    end
  end

  def can?(%User{} = user, :delete, %{hint: :link, domain_id: domain_id}) do
    Permissions.authorized?(user, :manage_ingest_relations, domain_id)
  end

  def can?(%User{} = user, :create_link, %{ingest: ingest_id}) do
    with %{domain_id: domain_id} <-
      Ingests.get_ingest!(String.to_integer(ingest_id)) do
      Permissions.authorized?(user, :manage_ingest_relations, domain_id)
    else
      error ->
        Logger.error("In LinkAbilities.can?/3 :create_link Link... #{inspect(error)}")
    end
  end

  def can?(%User{} = user, :create_link, %{domain_id: domain_id}) do
    Permissions.authorized?(user, :manage_ingest_relations, domain_id)
  end
end
