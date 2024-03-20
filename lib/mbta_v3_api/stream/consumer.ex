defmodule MBTAV3API.Stream.Consumer do
  use GenStage

  require Logger
  alias MBTAV3API.Stream

  defmodule State do
    @type t :: %__MODULE__{
            data: Stream.State.t(),
            destination: pid() | Phoenix.PubSub.topic(),
            type: module(),
            throttle: %{ms: integer(), last_send: integer() | nil, timer: reference() | nil}
          }
    defstruct [:data, :destination, :type, :throttle]
  end

  def start_link(opts) do
    {start_opts, opts} = Keyword.split(opts, [:name])
    GenStage.start_link(__MODULE__, opts, start_opts)
  end

  @impl GenStage
  def init(opts) do
    subscribe_to = Keyword.fetch!(opts, :subscribe_to)

    throttle_ms =
      Keyword.get(
        opts,
        :throttle_ms,
        Keyword.fetch!(
          Application.get_env(:mobile_app_backend, __MODULE__),
          :default_throttle_ms
        )
      )

    state = %State{
      data: Stream.State.new(),
      destination: Keyword.fetch!(opts, :destination),
      type: Keyword.fetch!(opts, :type),
      throttle: %{ms: throttle_ms, last_send: nil, timer: nil}
    }

    {:consumer, state, subscribe_to: subscribe_to}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    data = Stream.State.apply_events(state.data, events)

    now = System.monotonic_time(:millisecond)

    action_now =
      cond do
        is_nil(state.throttle.last_send) ->
          :send_now

        state.throttle.last_send + state.throttle.ms <= now ->
          :send_now

        is_nil(state.throttle.timer) ->
          send_at = state.throttle.last_send + state.throttle.ms
          {:send_at, send_at}

        true ->
          nil
      end

    throttle =
      case action_now do
        :send_now ->
          send_update(data, state.destination)
          %{state.throttle | last_send: now}

        {:send_at, send_at} ->
          ref = Process.send_after(self(), :send_update, send_at, abs: true)
          %{state.throttle | timer: ref}

        nil ->
          state.throttle
      end

    {:noreply, [], %{state | data: data, throttle: throttle}}
  end

  @impl true
  def handle_call(:get_data, _from, state) do
    {:reply, state.data, [], state}
  end

  @impl true
  def handle_info(:send_update, state) do
    now = System.monotonic_time(:millisecond)
    send_update(state.data, state.destination)
    throttle = %{state.throttle | last_send: now, timer: nil}
    {:noreply, [], %{state | throttle: throttle}}
  end

  defp send_update(data, destination) do
    message = {:stream_data, data}

    case destination do
      pid when is_pid(pid) -> send(pid, message)
      topic when is_binary(topic) -> MBTAV3API.Stream.PubSub.broadcast!(topic, message)
    end

    :ok
  end
end
