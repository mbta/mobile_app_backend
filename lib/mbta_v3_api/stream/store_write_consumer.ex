defmodule MBTAV3API.Stream.StoreWriteConsumer do
  use GenStage

  alias MBTAV3API.Stream

  defmodule State do
    @type t :: %__MODULE__{
            data: Stream.State.t(),
            destination: pid() | Phoenix.PubSub.topic(),
            type: module(),
            # TODO: more specific type / behavior for store
            store: module(),
            scope: map()
          }
    defstruct [:data, :destination, :store, :scope, :type]
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
      store: Keyword.fetch!(opts, :store),
      type: Keyword.fetch!(opts, :type)
    }

    {:consumer, state, subscribe_to: subscribe_to}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    data =
      events
      |> Enum.map(&MBTAV3API.Stream.State.parse_event(&1))
      |> state.store.update(state.scope)

    # TODO: if first event then broadcast
    {:noreply, [], %{state | data: data}}
  end

  @impl true
  def handle_call(:get_data, _from, state) do
    {:reply, state.data, [], state}
  end
end
