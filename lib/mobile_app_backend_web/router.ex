defmodule MobileAppBackendWeb.Router do
  use MobileAppBackendWeb, :router
  import Oban.Web.Router
  import Phoenix.LiveDashboard.Router
  import MobileAppBackendWeb.UserAuth

  @redirect_http Application.compile_env(:mobile_app_backend, :redirect_http?)

  pipeline :redirect_prod_http do
    if @redirect_http do
      plug(Plug.SSL, rewrite_on: [:x_forwarded_proto])
    end
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :redirect_prod_http
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MobileAppBackendWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug(MobileAppBackendWeb.Plugs.Etag)
  end

  pipeline :require_developer do
    plug :require_roles, required_roles: [:developer]
  end

  scope "/", MobileAppBackendWeb do
    get("/_health", HealthController, :index)

    get(
      "/.well-known/apple-app-site-association",
      DeepLinkController,
      :apple_app_site_association
    )

    get("/.well-known/assetlinks.json", DeepLinkController, :assetlinks_json)
  end

  scope "/api/protected", MobileAppBackendWeb do
    pipe_through([:api])
    get("/config", ClientConfigController, :config)
  end

  # Other scopes may use custom stacks.
  scope "/api", MobileAppBackendWeb do
    pipe_through :api
    get("/global", GlobalController, :show)

    post(
      "/notifications/subscriptions/accessibility",
      NotificationSubscriptionsController,
      :set_include_accessibility
    )

    post("/notifications/subscriptions/write", NotificationSubscriptionsController, :write)
    get("/route/stop-graph", RouteController, :stop_graph)
    get("/schedules", ScheduleController, :schedules)
    get("/schedules/next", NextScheduleController, :next_schedule)
    get("/search/query", SearchController, :query)
    get("/search/routes", SearchController, :routes)
    get("/shapes/map-friendly/rail", ShapesController, :rail)
    get("/shapes/rail", ShapesController, :rail)
    get("/stop/map", StopController, :map)
    get("/trip", TripController, :trip)
    get("/trip/map", TripController, :map)
    get("/trip/map-friendly", TripController, :map_friendly)
  end

  scope "/dev", MobileAppBackendWeb do
    pipe_through [:browser, :fetch_current_user, :require_authenticated_user, :require_developer]

    get "/", DevController, :home
    live_dashboard "/dashboard", metrics: MobileAppBackendWeb.Telemetry
    oban_dashboard("/oban")
  end

  scope "/dev", MobileAppBackendWeb do
    pipe_through [:browser, :fetch_current_user]

    get "/*_", DevController, :not_found
  end

  scope "/auth", MobileAppBackendWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/:provider", AuthController, :request
  end

  scope "/auth", MobileAppBackendWeb do
    pipe_through [:browser]

    get "/:provider/callback", AuthController, :callback
  end

  scope "/", MobileAppBackendWeb do
    pipe_through :browser

    get "/", DeepLinkController, :root
    get "/t-alert", DeepLinkController, :t_alert_cta
    get "/s/:stop_id/*_", DeepLinkController, :stop
    get "/stop/:stop_id/*_", DeepLinkController, :stop
    get "/a/*path_params", DeepLinkController, :alert
    get "/alert/*path_params", DeepLinkController, :alert
    get "/c/:campaign_id/*_", DeepLinkController, :campaign
    get "/:stop_id/*_", DeepLinkController, :stop
  end
end
