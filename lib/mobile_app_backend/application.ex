defmodule MobileAppBackend.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Logger.add_handlers(:mobile_app_backend)

    start_global_cache? =
      Application.get_env(:mobile_app_backend, :start_global_cache?, true)

    children =
      [
        MobileAppBackendWeb.Telemetry,
        {DNSCluster,
         query: Application.get_env(:mobile_app_backend, :dns_cluster_query) || :ignore},
        Supervisor.child_spec({Phoenix.PubSub, name: MobileAppBackend.PubSub},
          id: :general_pubsub
        ),
        {Finch,
         name: Finch.CustomPool,
         pools: %{
           :default => [size: 200, count: 10, start_pool_metrics?: true]
         }},
        {MBTAV3API.ResponseCache, []},
        {MBTAV3API.RepositoryCache, []},
        MBTAV3API.Supervisor,
        {MobileAppBackend.Health.FinchPool, pool_name: Finch.CustomPool},
        # TODO: Enable this once DB is created in deployed environments
        #  MobileAppBackend.Repo,
        # {Ecto.Migrator, repos: Application.fetch_env!(:mobile_app_backend, :ecto_repos)},
        {MobileAppBackend.Search.Algolia.Cache, []},
        {MobileAppBackend.Health.Cache, cache: MobileAppBackend.Search.Algolia.Cache},
        MobileAppBackend.MapboxTokenRotator,
        MobileAppBackend.Alerts.Registry,
        MobileAppBackend.Predictions.Registry,
        MobileAppBackend.Vehicles.Registry
      ] ++
        if Application.get_env(:mobile_app_backend, :start_pub_subs?, true) do
          [
            MobileAppBackend.Alerts.PubSub,
            MobileAppBackend.Vehicles.PubSub,
            MobileAppBackend.Predictions.PubSub
          ]
        else
          []
        end ++
        if start_global_cache? do
          [MobileAppBackend.GlobalDataCache]
        else
          []
        end ++
        if Application.get_env(:mobile_app_backend, :start_alerts_last_fresh_store?, true) do
          [MobileAppBackend.Health.Checker.Alerts.LastFreshStore]
        else
          []
        end ++
        [
          # Start to serve requests, typically the last entry
          MobileAppBackendWeb.Endpoint
        ]

    :ok = MobileAppBackend.FinchTelemetryLogger.attach()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MobileAppBackend.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MobileAppBackendWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
