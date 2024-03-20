defmodule MBTAV3API.Stream.Consumer do
  use GenStage

  alias MBTAV3API.Stream

  defmodule State do
    @type t :: %__MODULE__{
            data: Stream.State.t(),
            destination: pid() | Phoenix.PubSub.topic(),
            type: module(),
            throttler: GenServer.server()
          }
    defstruct [:data, :destination, :type, :throttler]
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
        Keyword.fetch!(Application.get_env(:mobile_app_backend, __MODULE__), :default_throttle_ms)
      )

    {:ok, throttler} =
      MobileAppBackend.Throttler.start_link(target: self(), cast: :send_update, ms: throttle_ms)

    state = %State{
      data: Stream.State.new(),
      destination: Keyword.fetch!(opts, :destination),
      type: Keyword.fetch!(opts, :type),
      throttler: throttler
    }

    {:consumer, state, subscribe_to: subscribe_to}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    data = Stream.State.apply_events(state.data, events)

    MobileAppBackend.Throttler.request(state.throttler)

    {:noreply, [], %{state | data: data}}
  end

  @impl true
  def handle_cast(:send_update, state) do
    case state.destination do
      pid when is_pid(pid) ->
        send(pid, {:stream_data, state.data})

      topic when is_binary(topic) ->
        Stream.PubSub.broadcast!(topic, {:stream_data, topic, state.data})
    end

    {:noreply, [], state}
  end

  @impl true
  def handle_call(:get_data, _from, state) do
    {:reply, state.data, [], state}
  end
end
