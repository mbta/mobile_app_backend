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

  pipeline :jsonapi do
    plug JSONAPI.EnsureSpec
    plug JSONAPI.Deserializer
    plug JSONAPI.UnderscoreParameters
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

    get("/route/by-stop/:stop_id", RouteController, :by_stop)
  end

  scope "/jsonapi", MobileAppBackendWeb do
    pipe_through :jsonapi

    resources("/stop", StopController, only: [:show])
  end

  scope "/graphql" do
    pipe_through :api

    forward "/graphiql", Absinthe.Plug.GraphiQL,
      schema: MobileAppBackendWeb.Schema,
      interface: :playground

    forward "/", Absinthe.Plug, schema: MobileAppBackendWeb.Schema
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
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
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
