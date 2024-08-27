defmodule MobileAppBackend.StopPredictions.Supervisor do
  use DynamicSupervisor

  require Logger
  alias MobileAppBackend.StopPredictions

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_instance(args) do
    # TODO - remove match
    DynamicSupervisor.start_child(__MODULE__, {StopPredictions.PubSub, args})
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
