defmodule MBTAV3API.Stream.ConsumerToStore do
  @moduledoc """
  Consume ServerSentEvents from a V3 API Stream and passes those events to
  Store that tracks the state of the world of that stream.

  `store:` - MBTAV3API.Store to record the stream data in
  `scope:` - The scope of the stream data of that stream - any filters applied. For example, `[route_id: 66]`

  based on https://github.com/mbta/dotcom/blob/main/lib/predictions/stream.ex
  """
  use GenStage

  alias MBTAV3API.Stream

  defmodule State do
    @type store_module :: module()

    @type t :: %__MODULE__{
            data: Stream.State.t(),
            destination: pid() | Phoenix.PubSub.topic(),
            store: store_module(),
            scope: keyword(),
            type: module()
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
    events
    |> Enum.map(&MBTAV3API.Stream.State.parse_event(&1))
    |> Enum.each(&process_event(&1, state))

    {:noreply, [], state}
  end

  defp process_event({:remove, data}, state) do
    state.store.process_remove(data)
  end

  defp process_event({:reset, data}, state) do
    state.store.process_reset(data, state.scope)

    case state.destination do
      pid when is_pid(pid) ->
        send(pid, :reset_event)

      topic when is_binary(topic) ->
        Stream.PubSub.broadcast!(topic, :reset_event)
    end
  end

  defp process_event({event_type, data}, state) do
    state.store.process_upsert(event_type, data)
  end

  @impl true
  def handle_call(:get_data, _from, state) do
    {:reply, state.store.fetch(state.scope), [], state}
  end
end
