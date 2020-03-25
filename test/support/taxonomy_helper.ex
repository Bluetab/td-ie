defmodule TdIe.TaxonomyHelper do
  @moduledoc """
  Helper functions on taxonomy iteration
  """
  alias TdCache.TaxonomyCache

  @valid_attrs %{
    id: :random.uniform(1_000_000),
    name: "domain name",
    parent_ids: [],
    updated_at: DateTime.utc_now()
  }

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
