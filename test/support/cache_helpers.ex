defmodule CacheHelpers do
  @moduledoc """
  Support creation of domains in cache
  """

  import ExUnit.Callbacks, only: [on_exit: 1]
  import TdIe.Factory

  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdCache.UserCache

  def put_domain(params \\ %{}) do
    %{id: domain_id} = domain = build(:domain, params)
    on_exit(fn -> TaxonomyCache.delete_domain(domain_id, clean: true) end)
    TaxonomyCache.put_domain(domain, publish: false)
    domain
  end

  def put_user(params \\ %{}) do
    %{id: user_id} = user = build(:user, params)
    on_exit(fn -> UserCache.delete(user_id) end)
    UserCache.put(user)
    user
  end

  def insert_template(params \\ %{}) do
    %{id: id} = template = build(:template, params)
    on_exit(fn -> TemplateCache.delete(id) end)
    {:ok, _} = TemplateCache.put(template, publish: false)
    template
  end

  def put_session_permissions(%{jti: session_id, exp: exp}, %{} = permissions_by_domain_id) do
    put_session_permissions(session_id, exp, permissions_by_domain_id)
  end

  def put_session_permissions(%{} = claims, domain_id, permissions) do
    permissions_by_domain_id = Map.new(permissions, &{to_string(&1), [domain_id]})
    put_session_permissions(claims, permissions_by_domain_id)
  end

  def put_session_permissions(session_id, exp, permissions_by_domain_id) do
    on_exit(fn -> TdCache.Redix.del!("session:#{session_id}:permissions") end)
    TdCache.Permissions.cache_session_permissions!(session_id, exp, permissions_by_domain_id)
  end

  def put_default_permissions(permissions) do
    on_exit(fn -> TdCache.Permissions.put_default_permissions([]) end)
    TdCache.Permissions.put_default_permissions(permissions)
  end
end
