import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: System.get_env("SENTRY_ENV", "local"),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!()

config :mobile_app_backend, :deep_links,
  android_cert_fingerprint: System.get_env("ANDROID_CERT_FINGERPRINT"),
  android_package_name: System.get_env("ANDROID_PACKAGE_NAME"),
  dotcom_root: System.get_env("DOTCOM_ROOT"),
  ios_appid: System.get_env("IOS_APPID")

case System.get_env("MAPBOX_PRIMARY_TOKEN") do
  primary_token when is_binary(primary_token) and primary_token != "" ->
    config :mobile_app_backend, MobileAppBackend.ClientConfig,
      mapbox_primary_token: primary_token,
      mapbox_username: System.get_env("MAPBOX_USERNAME"),
      token_expiration: :timer.minutes(30),
      token_renewal: :timer.minutes(25)

  _ ->
    config :mobile_app_backend, MobileAppBackend.ClientConfig,
      mapbox_public_token: System.get_env("MAPBOX_PUBLIC_TOKEN")
end

if config_env() == :dev do
  config :logger, :console, level: String.to_existing_atom(System.get_env("LOG_LEVEL", "debug"))
end

if config_env() != :test do
  # mbta_v3_api configuration in disguise
  config :mobile_app_backend,
    base_url: System.get_env("API_URL"),
    api_key: System.get_env("API_KEY")

  config :mobile_app_backend, MobileAppBackend.Search.Algolia,
    app_id: System.get_env("ALGOLIA_APP_ID"),
    search_key: System.get_env("ALGOLIA_SEARCH_KEY"),
    base_url: System.get_env("ALGOLIA_READ_URL")

  # open_trip_planner_client configuration in disguise
  config :mobile_app_backend,
    otp_url: System.get_env("OTP_URL")
end

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/mobile_app_backend start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :mobile_app_backend, MobileAppBackendWeb.Endpoint, server: true
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :mobile_app_backend, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :mobile_app_backend, MobileAppBackendWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :mobile_app_backend, MobileAppBackendWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your endpoint, ensuring
  # no data is ever sent via http, always redirecting to https:
  #
  #     config :mobile_app_backend, MobileAppBackendWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
