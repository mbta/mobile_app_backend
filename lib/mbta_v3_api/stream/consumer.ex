defmodule MBTAV3API.Stream.Consumer do
  use GenStage

  alias MBTAV3API.Stream

  defmodule State do
    @type t :: %__MODULE__{
            data: Stream.State.t(),
            send_to: pid(),
            type: module()
          }
    defstruct [:data, :send_to, :type]
  end

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl GenStage
  def init(opts) do
    subscribe_to = Keyword.fetch!(opts, :subscribe_to)

    state = %State{
      data: Stream.State.new(),
      send_to: Keyword.fetch!(opts, :send_to),
      type: Keyword.fetch!(opts, :type)
    }

    {:consumer, state, subscribe_to: subscribe_to}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    data = Stream.State.apply_events(state.data, events)

    message = {:stream_data, data}
    send(state.send_to, message)

    {:noreply, [], %{state | data: data}}
  end
end
