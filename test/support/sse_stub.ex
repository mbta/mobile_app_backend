defmodule Test.Support.SSEStub do
  @moduledoc """
  A `GenStage` producer that sends events on request.
  """

  use GenStage

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(args) do
    {start_args, init_args} = Keyword.split(args, [:name])
    GenStage.start_link(__MODULE__, init_args, start_args)
  end

  @doc """
  Gets the pid of the SSEStub running inside the given `MBTAV3API.Stream.Instance`.
  """
  @spec get_from_instance(Supervisor.supervisor()) :: pid()
  def get_from_instance(instance) do
    {_id, child, _type, [__MODULE__]} =
      instance
      |> Supervisor.which_children()
      |> Enum.find(fn {_id, _child, _type, [module]} -> module == __MODULE__ end)

    child
  end

  @doc """
  Gets the args that were passed to `init` for this stage.
  """
  @spec get_args(GenStage.stage()) :: Keyword.t()
  def get_args(stage) do
    GenStage.call(stage, :get_args)
  end

  @doc """
  Push the given events to subscribers.
  """
  @spec push_events(GenStage.stage(), [ServerSentEventStage.Event.t()]) :: :ok
  def push_events(stage, events) do
    GenStage.cast(stage, {:push_events, events})
  end

  @impl true
  def init(args) do
    {:producer, %{args: args}}
  end

  @impl true
  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  @impl true
  def handle_call(:get_args, _from, state) do
    {:reply, state.args, [], state}
  end

  @impl true
  def handle_cast({:push_events, events}, state) do
    {:noreply, events, state}
  end
end
