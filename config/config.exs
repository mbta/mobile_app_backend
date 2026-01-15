# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mobile_app_backend,
  ecto_repos: [MobileAppBackend.Repo]

config :mobile_app_backend,
  generators: [timestamp_type: :utc_datetime]

config :mobile_app_backend, alerts_broadcast_interval_ms: 500
config :mobile_app_backend, predictions_broadcast_interval_ms: 5_000
config :mobile_app_backend, vehicles_broadcast_interval_ms: 500

config :mobile_app_backend, MBTAV3API.ResponseCache,
  gc_interval: :timer.hours(1),
  allocated_memory: 250_000_000

config :mobile_app_backend, MBTAV3API.RepositoryCache,
  gc_interval: :timer.hours(2),
  allocated_memory: 2_000_000_000

config :mobile_app_backend, MobileAppBackend.Search.Algolia.Cache,
  gc_interval: :timer.hours(6),
  allocated_memory: 250_000_000,
  stats: true

# Configures the endpoint
config :mobile_app_backend, MobileAppBackendWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MobileAppBackendWeb.ErrorHTML, json: MobileAppBackendWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MobileAppBackend.PubSub,
  live_view: [signing_salt: "EPNVgKKu"]

config :mobile_app_backend, MobileAppBackend.Search.Algolia,
  route_index: "routes_test",
  stop_index: "stops_test"

config :mobile_app_backend, MobileAppBackend.GlobalDataCache, update_ms: :timer.minutes(5)

config :mobile_app_backend, Oban,
  engine: Oban.Engines.Basic,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"@daily", MobileAppBackend.Notifications.DeliveredNotificationPruner},
       {"* * * * *", MobileAppBackend.Notifications.Scheduler}
     ],
     timezone: "America/New_York"},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)},
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    Oban.Plugins.Reindexer
  ],
  queues: [default: 10],
  repo: MobileAppBackend.Repo

config :mobile_app_backend, :logger, [
  {:handler, :sentry_handler, Sentry.LoggerHandler,
   %{
     config: %{metadata: :all}
   }}
]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Use Req for making HTTP requests
config :mobile_app_backend, MobileAppBackend.HTTP, Req

# Use ServerSentEventStage for making SSE requests
config :mobile_app_backend, MobileAppBackend.SSE, ServerSentEventStage

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
