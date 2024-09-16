defmodule MobileAppBackend.FinchPoolHealth do
  use GenServer
  require Logger

  @interval :timer.seconds(5)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    pool_name = Keyword.fetch!(opts, :pool_name)
    get_pool_status_fn = Keyword.get(opts, :get_pool_status_fn, &Finch.get_pool_status/2)
    Process.send_after(self(), :check, @interval)

    {:ok, %{pool_name: pool_name, get_pool_status_fn: get_pool_status_fn}}
  end

  @impl true
  def handle_info(:check, %{pool_name: pool_name, get_pool_status_fn: get_pool_status_fn} = state) do
    v3_api_url = Application.get_env(:mobile_app_backend, :base_url)

    case get_pool_status_fn.(pool_name, v3_api_url) do
      {:error, :not_found} ->
        Logger.info("#{__MODULE__} pool not found")

      {:error, error} ->
        Logger.warning("#{__MODULE__} pool health error=#{inspect(error)}")

      {:ok, statuses} ->
        Enum.each(statuses, fn status ->
          Logger.info(
            "#{__MODULE__} pool_health available_connections=#{status.available_connections} in_use_connections=#{status.in_use_connections} pool_index=#{status.pool_index} pool_size=#{status.pool_size}"
          )
        end)
    end

    Process.send_after(self(), :check, @interval)

    {:noreply, state}
  end
end
