defmodule MBTAV3API.Supervisor do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    start_predictions_store? =
      Application.get_env(:mobile_app_backend, :start_predictions_store?, true)

    children =
      if start_predictions_store? do
        [MBTAV3API.Store.Predictions]
      else
        []
      end ++
        [
          MBTAV3API.Stream.Registry,
          MBTAV3API.Stream.PubSub,
          MBTAV3API.Stream.Supervisor,
          MBTAV3API.Stream.Health
        ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
