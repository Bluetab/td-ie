defmodule TdIeWeb.Router do
  use TdIeWeb, :router

  @endpoint_url "#{Application.get_env(:td_ie, TdIeWeb.Endpoint)[:url][:host]}:#{
                  Application.get_env(:td_ie, TdIeWeb.Endpoint)[:url][:port]
                }"

  pipeline :api do
    plug(TdIe.Auth.Pipeline.Unsecure)
    plug(TdIeWeb.Locale)
    plug(:accepts, ["json"])
  end

  pipeline :api_secure do
    plug(TdIe.Auth.Pipeline.Secure)
  end

  pipeline :api_authorized do
    plug(TdIe.Auth.CurrentUser)
    plug(Guardian.Plug.LoadResource)
  end

  scope "/api/swagger" do
    forward("/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :td_ie, swagger_file: "swagger.json")
  end

  scope "/api", TdIeWeb do
    pipe_through(:api)
    get("/ping", PingController, :ping)
    post("/echo", EchoController, :echo)
  end

  scope "/api", TdIeWeb do
    pipe_through([:api, :api_secure, :api_authorized])

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
    end

    post("/ingest_versions/search", IngestVersionController, :search)

    get("/ingest_filters", IngestFilterController, :index)
    post("/ingest_filters/search", IngestFilterController, :search)

    post("/ingests/add_execution", IngestExecutionController, :add_execution_by_name)

    resources("/ingests/comments", CommentController, except: [:new, :edit])
    get("/ingests/index/:status", IngestController, :index_status)
    get("/ingests/search", IngestController, :search)
    get("/ingests/domains/:domain_id", IngestController, :index_children_ingest)

    resources "/ingests", IngestController, except: [:index, :new, :edit, :delete] do
      patch("/status", IngestController, :update_status)
      resources("/ingest_executions", IngestExecutionController, except: [:new, :edit])
    end

    get("/ingests/search/reindex_all", SearchController, :reindex_all)
  end

  def swagger_info do
    %{
      schemes: ["http"],
      info: %{
        version: "1.0",
        title: "TdIe"
      },
      host: @endpoint_url,
      securityDefinitions: %{
        bearer: %{
          type: "apiKey",
          name: "Authorization",
          in: "header"
        }
      },
      security: [
        %{
          bearer: []
        }
      ]
    }
  end
end
