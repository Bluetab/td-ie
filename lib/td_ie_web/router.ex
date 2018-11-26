defmodule TdIeWeb.Router do
  use TdIeWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", TdIeWeb do
    pipe_through :api
  end
end
