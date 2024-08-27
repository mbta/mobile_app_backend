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
    {:ok, _} = GenStage.start_link(__MODULE__, opts, start_opts)
  end

  @impl GenStage
  def init(opts) do
    subscribe_to = Keyword.fetch!(opts, :subscribe_to)

    state = %State{
      data: Stream.State.new(),
      destination: Keyword.fetch!(opts, :destination),
      store: Keyword.fetch!(opts, :store),
      scope: Keyword.fetch!(opts, :scope),
      type: Keyword.fetch!(opts, :type)
    }

    {:consumer, state, subscribe_to: subscribe_to}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    data =
      events
      |> Enum.map(&MBTAV3API.Stream.State.parse_event(&1))
      |> state.store.process_event(state.scope)

    # TODO: if first event then broadcast
    {:noreply, [], %{state | data: data}}
  end

  @impl
  def handle_call(:get_data, _from, state) do
    {:reply, state.store.fetch(state.scope), [], state}
  end
end
