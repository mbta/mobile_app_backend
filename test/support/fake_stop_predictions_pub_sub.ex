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

    GenServer.start_link(__MODULE__, data,
      name: MobileAppBackend.StopPredictions.Registry.via_name(stop_id)
    )
  end

  @impl true
  def init(data) do
    {:ok, data}
  end

  @impl true
  def handle_call(:get_data, _from, state) do
    {:reply, state, state}
  end
end
