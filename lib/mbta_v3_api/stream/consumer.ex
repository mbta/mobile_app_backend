defmodule MBTAV3API.Stream.Consumer do
  use GenStage

  defmodule State do
    @type t :: %__MODULE__{send_to: pid()}
    defstruct [:send_to]
  end

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl GenStage
  def init(opts) do
    subscribe_to = Keyword.fetch!(opts, :subscribe_to)
    state = %State{send_to: Keyword.fetch!(opts, :send_to)}
    {:consumer, state, subscribe_to: subscribe_to}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    message = {:stream_events, Enum.map(events, &MBTAV3API.Stream.Event.parse/1)}
    send(state.send_to, message)

    {:noreply, [], state}
  end
end
