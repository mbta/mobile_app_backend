defmodule MBTAV3API.Stream.Consumer do
  use GenStage

  alias MBTAV3API.Stream

  defmodule State do
    @type t :: %__MODULE__{
            data: Stream.State.t(),
            destination: pid() | Phoenix.PubSub.topic(),
            type: module()
          }
    defstruct [:data, :destination, :type]
  end

  def start_link(opts) do
    {start_opts, opts} = Keyword.split(opts, [:name])
    GenStage.start_link(__MODULE__, opts, start_opts)
  end

  @impl GenStage
  def init(opts) do
    subscribe_to = Keyword.fetch!(opts, :subscribe_to)

    state = %State{
      data: Stream.State.new(),
      destination: Keyword.fetch!(opts, :destination),
      type: Keyword.fetch!(opts, :type)
    }

    {:consumer, state, subscribe_to: subscribe_to}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    data = Stream.State.apply_events(state.data, events)

    message = {:stream_data, data}

    case state.destination do
      pid when is_pid(pid) -> send(pid, message)
      topic when is_binary(topic) -> MBTAV3API.Stream.PubSub.broadcast!(topic, message)
    end

    {:noreply, [], %{state | data: data}}
  end

  @impl true
  def handle_call(:get_data, _from, state) do
    {:reply, state.data, [], state}
  end
end
