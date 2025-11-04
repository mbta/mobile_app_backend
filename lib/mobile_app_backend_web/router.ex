defmodule MobileAppBackendWeb.Router do
  use MobileAppBackendWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
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
    get("/alerts", AlertsController, :show)
    get("/global", GlobalController, :show)
    get("/nearby", NearbyController, :show)

    post(
      "/notifications/subscriptions/accessibility",
      NotificationSubscriptionsController,
      :set_include_accessibility
    )

    post("/notifications/subscriptions/write", NotificationSubscriptionsController, :write)
    get("/route/stop-graph", RouteController, :stop_graph)
    get("/schedules", ScheduleController, :schedules)
    get("/search/query", SearchController, :query)
    get("/search/routes", SearchController, :routes)
    get("/shapes/map-friendly/rail", ShapesController, :rail)
    get("/shapes/rail", ShapesController, :rail)
    get("/stop/map", StopController, :map)
    get("/trip", TripController, :trip)
    get("/trip/map", TripController, :map)
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:mobile_app_backend, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Oban.Web.Router
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MobileAppBackendWeb.Telemetry
      oban_dashboard("/oban")
    end
  end

  scope "/", MobileAppBackendWeb do
    pipe_through :browser

    get "/", DeepLinkController, :root
    get "/t-alert", DeepLinkController, :t_alert_cta
    get "/s/*_", DeepLinkController, :nav_path
    get "/stop/*_", DeepLinkController, :nav_path
    get "/a/*_", DeepLinkController, :nav_path
    get "/alert/*_", DeepLinkController, :nav_path
    get "/c/*_", DeepLinkController, :nav_path
    get "/:stop_id/*_", DeepLinkController, :root_stop
  end
end
