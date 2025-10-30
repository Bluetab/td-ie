defmodule TdIe.RepoTest do
  use ExUnit.Case, async: true

  alias TdIe.Repo

  describe "init/2" do
    test "init function returns correct configuration" do
      result = Repo.init(:test, [])

      assert is_tuple(result)
      assert elem(result, 0) == :ok

      config = elem(result, 1)
      assert is_list(config)
      # Check for common Ecto.Repo configuration keys
      assert Keyword.has_key?(config, :url) || Keyword.has_key?(config, :adapter)
    end
  end
end
