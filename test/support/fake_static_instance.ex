defmodule Test.Support.FakeStaticInstance do
  use GenServer

  def child_spec(opts) do
    topic = Keyword.fetch!(opts, :topic)

    Supervisor.child_spec(
      %{id: {__MODULE__, topic}, start: {__MODULE__, :start_link, [opts]}},
      []
    )
  end

  def start_link(opts) do
    data = Keyword.fetch!(opts, :data)
    topic = Keyword.fetch!(opts, :topic)
    GenServer.start_link(__MODULE__, data, name: MBTAV3API.Stream.Registry.via_name(topic))
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
