defmodule TdIeWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common datastructures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  import TdIeWeb.Authentication, only: :functions

  alias Ecto.Adapters.SQL.Sandbox
  alias Phoenix.ConnTest

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import TdIe.Factory

      alias TdIeWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint TdIeWeb.Endpoint
    end
  end

  setup tags do
    :ok = Sandbox.checkout(TdIe.Repo)

    unless tags[:async] do
      Sandbox.mode(TdIe.Repo, {:shared, self()})

      parent = self()

      Enum.each([TdIe.Cache.IngestLoader, TdIe.Search.IndexWorker], fn worker ->
        case Process.whereis(worker) do
          nil ->
            nil

          pid ->
            on_exit(fn -> worker.ping(20_000) end)
            Sandbox.allow(TdIe.Repo, parent, pid)
        end
      end)
    end

    cond do
      tags[:admin_authenticated] ->
        user = create_user(is_admin: true)
        create_user_auth_conn(user)

      tags[:authenticated_user] ->
        user = create_user(is_admin: false)
        create_user_auth_conn(user)

      true ->
        {:ok, conn: ConnTest.build_conn()}
    end
  end
end
