defmodule MBTAV3API.Stream.Health do
  use GenServer

  @interval :timer.seconds(5)

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  @impl true
  def init(_) do
    Process.send_after(self(), :check, @interval)

    {:ok, nil}
  end

  @impl true
  def handle_info(:check, _) do
    MBTAV3API.Stream.Supervisor.log_health()
    Process.send_after(self(), :check, @interval)

    {:noreply, nil}
  end
end
