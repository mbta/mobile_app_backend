defmodule Test.Support.FakeStopPredictions.PubSub do
  use GenServer

  def child_spec(opts) do
    stop_id = Keyword.fetch!(opts, :stop_id)

    Supervisor.child_spec(
      %{id: {__MODULE__, stop_id}, start: {__MODULE__, :start_link, [opts]}},
      []
    )
  end

  def start_link(opts) do
    data = Keyword.fetch!(opts, :data)
    stop_id = Keyword.fetch!(opts, :stop_id)
    predictions_by_route = Keyword.get(opts, :predictions_by_route, %{})

    GenServer.start_link(__MODULE__, %{data: data, predictions_by_route: predictions_by_route},
      name: MobileAppBackend.StopPredictions.Registry.via_name(stop_id)
    )
  end

  @impl true
  def init(data) do
    {:ok, data}
  end

  @impl true
  def handle_call(:get_predictions_by_route, _from, state) do
    {:reply, Map.fetch!(state, :predictions_by_route), state}
  end
end
