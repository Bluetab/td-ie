defmodule TdIeWeb.Router do
  use TdIeWeb, :router

  pipeline :api do
    plug TdIe.Auth.Pipeline.Unsecure
    plug TdIeWeb.Locale
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug TdIe.Auth.Pipeline.Secure
  end

  scope "/api", TdIeWeb do
    pipe_through :api
    get("/ping", PingController, :ping)
    post("/echo", EchoController, :echo)
  end

  scope "/api", TdIeWeb do
    pipe_through [:api, :api_auth]

    post("/ingest_versions/csv", IngestVersionController, :csv)
    put("/ingest_versions/:id", IngestVersionController, :update)

    resources "/ingest_versions", IngestVersionController, except: [:new, :edit, :update] do
      post("/submit", IngestVersionController, :send_for_approval)
      post("/publish", IngestVersionController, :publish)
      post("/reject", IngestVersionController, :reject)
      post("/deprecate", IngestVersionController, :deprecate)
      post("/version", IngestVersionController, :version)
      post("/redraft", IngestVersionController, :undo_rejection)
      get("/versions", IngestVersionController, :versions)
      resources("/links", IngestLinkController, only: [:delete])
      post("/links", IngestLinkController, :create_link)
    end

    post("/ingest_versions/search", IngestVersionController, :search)

    get("/ingest_filters", IngestFilterController, :index)
    post("/ingest_filters/search", IngestFilterController, :search)

    post("/ingests/add_execution", IngestExecutionController, :add_execution_by_name)

    get("/ingests/index/:status", IngestController, :index_status)
    get("/ingests/search", IngestController, :search)
    get("/ingests/domains/:domain_id", IngestController, :index_children_ingest)

    resources "/ingests", IngestController, except: [:index, :new, :edit, :delete] do
      patch("/status", IngestController, :update_status)
      resources("/ingest_executions", IngestExecutionController, except: [:new, :edit])
    end

    get("/ingests/search/reindex_all", SearchController, :reindex_all)
  end
end
