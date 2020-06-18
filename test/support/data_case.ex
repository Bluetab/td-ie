defmodule TdIe.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import Ecto
      import Ecto.Query
      import TdIe.DataCase
      import TdIe.Factory

      alias TdIe.Repo
    end
  end

  setup tags do
    :ok = Sandbox.checkout(TdIe.Repo)

    unless tags[:async] do
      Sandbox.mode(TdIe.Repo, {:shared, self()})

      parent = self()

      case Process.whereis(TdIe.Cache.IngestLoader) do
        nil -> nil
        pid -> Sandbox.allow(TdIe.Repo, parent, pid)
      end

      case Process.whereis(TdIe.Search.IndexWorker) do
        nil -> nil
        pid -> Sandbox.allow(TdIe.Repo, parent, pid)
      end
    end

    :ok
  end
end
