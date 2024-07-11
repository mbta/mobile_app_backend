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
  end

  scope "/", MobileAppBackendWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", MobileAppBackendWeb do
    get("/_health", HealthController, :index)
  end

  # Other scopes may use custom stacks.
  scope "/api", MobileAppBackendWeb do
    pipe_through :api
    get("/nearby", NearbyController, :show)
    get("/global", GlobalController, :show)
    get("/search/query", SearchController, :query)
    get("/shapes/rail", ShapesController, :rail)
    get("/shapes/map-friendly/rail", ShapesController, :rail)
    get("/stop/map", StopController, :map)
    get("/trip/map", TripController, :map)
    get("/schedules", ScheduleController, :schedules)
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:mobile_app_backend, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MobileAppBackendWeb.Telemetry
    end
  end
end
