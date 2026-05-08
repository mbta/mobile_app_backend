defmodule MobileAppBackend.Health.Cache do
  use GenServer
  require Logger

  @interval to_timeout(minute: 1)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    cache = Keyword.fetch!(opts, :cache)
    Process.send_after(self(), :check, @interval)

    {:ok, %{cache: cache}}
  end

  @impl true
  def handle_info(:check, %{cache: cache} = state) do
    case cache.info() do
      nil ->
        Logger.info("#{__MODULE__} cache=#{cache} cache stats disabled")

      {:ok, %{stats: %{hits: cache_hits, misses: cache_misses}}} ->
        Logger.info(
          "#{__MODULE__} cache=#{cache} cache_health hits=#{cache_hits} misses=#{cache_misses} hit_rate=#{cache_hits / max(cache_hits + cache_misses, 1)}"
        )

      {:error, error} ->
        Logger.warning("#{__MODULE__} error reading cache data #{inspect(error)}")
    end

    Process.send_after(self(), :check, @interval)

    {:noreply, state}
  end
end
