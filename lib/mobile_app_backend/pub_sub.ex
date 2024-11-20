defmodule MobileAppBackend.PubSub do
  @moduledoc """
  Common functions for broadcasting the latest state from realtime MBTAV3API.Stores
  to subscriber processes if the data has changed.
  """
  alias MBTAV3API.Store
  require Logger

  @typedoc """
  tuple {fetch_keys, format_fn} where format_fn transforms the data returned
  into the format expected by subscribers.
  """
  @type registry_value :: {Store.fetch_keys(), function()}

  @doc """
  Group registered pids by the data they are subscribed to.
  """
  @spec group_pids_by_target_data([{pid(), registry_value()}]) :: %{registry_value() => [pid()]}
  def group_pids_by_target_data(registry_entries) do
    Enum.group_by(
      registry_entries,
      fn {_, {fetch_keys, format_fn}} -> {fetch_keys, format_fn} end,
      fn {pid, _} -> pid end
    )
  end

  @doc """
  Broadcast the latest data to subscriber pids if the data has changed since they last received it.
  """
  @spec broadcast_latest_data(any(), atom(), registry_value(), [pid()], atom()) :: any()
  def broadcast_latest_data(
        latest_data,
        broadcast_message_name,
        registry_value,
        pids,
        last_dispatched_table_name
      ) do
    last_dispatched_entry = :ets.lookup(last_dispatched_table_name, registry_value)

    if !already_broadcast(last_dispatched_entry, latest_data) do
      broadcast(
        pids,
        latest_data,
        broadcast_message_name,
        registry_value,
        last_dispatched_table_name
      )
    end
  end

  defp already_broadcast([], _latest_data) do
    # Nothing has been broadcast yet
    false
  end

  defp already_broadcast([{_registry_key, old_data}], latest_data) do
    old_data == latest_data
  end

  defp broadcast(
         pids,
         data,
         broadcast_message_name,
         {fetch_keys, _format_fn} = registry_value,
         last_dispatched_table_name
       ) do
    Logger.info("#{__MODULE__} broadcasting to pids len=#{length(pids)}")

    {time_micros, _result} =
      :timer.tc(__MODULE__, :broadcast_to_pids, [
        pids,
        data,
        broadcast_message_name
      ])

    Logger.info(
      "#{__MODULE__} broadcast_to_pids fetch_keys=#{inspect(fetch_keys)} duration=#{time_micros / 1000}"
    )

    :ets.insert(last_dispatched_table_name, {registry_value, data})
  end

  def broadcast_to_pids(pids, data, broadcast_message_name) do
    Enum.each(
      pids,
      &send(
        &1,
        {broadcast_message_name, data}
      )
    )
  end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use GenServer

      broadcast_interval_ms = Keyword.fetch!(opts, :broadcast_interval_ms)

      # Any time there is a reset_event, broadcast so that subscribers are immediately
      # notified of the changes. This way, when the stream first starts,
      # consumers don't have to wait `:broadcast_interval_ms` to receive their first message.
      @impl true
      def handle_info(:reset_event, state) do
        send(self(), :broadcast)
        {:noreply, state, :hibernate}
      end

      def handle_info(:timed_broadcast, state) do
        send(self(), :broadcast)
        interval = unquote(broadcast_interval_ms)
        broadcast_timer(interval)
        {:noreply, state, :hibernate}
      end

      defp broadcast_timer(interval) do
        Process.send_after(self(), :timed_broadcast, interval)
      end
    end
  end
end
