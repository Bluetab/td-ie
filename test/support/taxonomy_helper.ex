defmodule TdIe.TaxonomyHelper do
  @moduledoc """
  Helper functions on taxonomy iteration
  """
  alias TdPerms.TaxonomyCache
  @valid_attrs %{id: 1, name: "domain name", parent_ids: []}

  def domain_fixture(attrs \\ %{}) do
    final_attrs =
      attrs
      |> Enum.into(@valid_attrs)

    final_attrs
      |> Map.get(:id)
      |> TaxonomyCache.delete_domain()

    final_attrs
      |> TaxonomyCache.put_domain()

    final_attrs
  end
end
