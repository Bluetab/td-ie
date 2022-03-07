defmodule TdIe.Canada.LinkAbilities do
  @moduledoc """
  Canada permissions model for Ingest Link resources
  """
  alias TdCache.Link
  alias TdIe.Auth.Claims
  alias TdIe.Ingests
  alias TdIe.Permissions

  require Logger

  def can?(%Claims{role: "admin"}, :create_link, _resource), do: true

  def can?(%Claims{role: "admin"}, _action, %Link{}), do: true

  def can?(%Claims{role: "admin"}, _action, %{hint: :link}), do: true

  def can?(%Claims{} = claims, :delete, %Link{source: "ingest:" <> ingest_id}) do
    case Ingests.get_ingest!(String.to_integer(ingest_id)) do
      %{domain_id: domain_id} ->
        Permissions.authorized?(claims, :manage_ingest_relations, domain_id)

      error ->
        Logger.error("In LinkAbilities.can?/3 :delete Link... #{inspect(error)}")
    end
  end

  def can?(%Claims{} = claims, :delete, %{hint: :link, domain_id: domain_id}) do
    Permissions.authorized?(claims, :manage_ingest_relations, domain_id)
  end

  def can?(%Claims{} = claims, :create_link, %{ingest: ingest_id}) do
    case Ingests.get_ingest!(String.to_integer(ingest_id)) do
      %{domain_id: domain_id} ->
        Permissions.authorized?(claims, :manage_ingest_relations, domain_id)

      error ->
        Logger.error("In LinkAbilities.can?/3 :create_link Link... #{inspect(error)}")
    end
  end

  def can?(%Claims{} = claims, :create_link, %{domain_id: domain_id}) do
    Permissions.authorized?(claims, :manage_ingest_relations, domain_id)
  end
end
