import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mobile_app_backend, MobileAppBackendWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "i2tUYeAO95DpQJMjLPg+aBuneGbF6hGMyTvth/i1csZT7LeeH6ZsWpDO9F9IkJ7f",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :mobile_app_backend,
  base_url: "https://api-dev.mbtace.com/",
  otp_url: "http://otp.example.com/"

config :mobile_app_backend, MobileAppBackend.Search.Algolia,
  app_id: "fake_app",
  search_key: "fake_key",
  base_url: "fake_url"

config :mobile_app_backend, MobileAppBackend.StopPredictions.PubSub, broadcast_interval_ms: 50

# Use server-sent events stub instead of real connections
config :mobile_app_backend, MobileAppBackend.SSE, Test.Support.SSEStub
