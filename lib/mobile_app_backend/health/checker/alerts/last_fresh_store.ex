defmodule MobileAppBackend.Health.Checker.Alerts.LastFreshStore do
  use GenServer

  @callback last_fresh_timestamp :: DateTime.t()
  @callback update_last_fresh_timestamp(DateTime.t()) :: :ok

  @type state :: DateTime.t()
  def start_link(opts \\ []) do
    Application.get_env(
      :mobile_app_backend,
      MobileAppBackend.Health.Checker.Alerts.LastFreshStore,
      MobileAppBackend.Health.Checker.Alerts.LastFreshStore.Impl
    ).start_link(opts)
  end

  @impl true
  def init(opts) do
    Application.get_env(
      :mobile_app_backend,
      MobileAppBackend.Health.Checker.Alerts.LastFreshStore,
      MobileAppBackend.Health.Checker.Alerts.LastFreshStore.Impl
    ).init(opts)
  end

  def last_fresh_timestamp do
    Application.get_env(
      :mobile_app_backend,
      MobileAppBackend.Health.Checker.Alerts.LastFreshStore,
      MobileAppBackend.Health.Checker.Alerts.LastFreshStore.Impl
    ).last_fresh_timestamp()
  end

  def update_last_fresh_timestamp(timestamp \\ DateTime.utc_now()) do
    Application.get_env(
      :mobile_app_backend,
      MobileAppBackend.Health.Checker.Alerts.LastFreshStore,
      MobileAppBackend.Health.Checker.Alerts.LastFreshStore.Impl
    ).update_last_fresh_timestamp(timestamp)
  end
end

defmodule MobileAppBackend.Health.Checker.Alerts.LastFreshStore.Impl do
  use GenServer

  alias MobileAppBackend.Health.Checker.Alerts.LastFreshStore

  @behaviour LastFreshStore

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts \\ []) do
    {:ok, Keyword.get(opts, :now, DateTime.utc_now())}
  end

  @impl true
  def last_fresh_timestamp do
    GenServer.call(__MODULE__, :get_last_fresh)
  end

  @impl true
  def update_last_fresh_timestamp(timestamp) do
    GenServer.call(__MODULE__, {:update_last_fresh_timestamp, timestamp})
  end

  @impl true
  def handle_call(:get_last_fresh, _request, last_fresh) do
    {:reply, last_fresh, last_fresh}
  end

  @impl true
  def handle_call({:update_last_fresh_timestamp, timestamp}, _request, _last_fresh) do
    {:reply, :ok, timestamp}
  end
end
