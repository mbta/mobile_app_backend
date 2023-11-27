defmodule Routes.Supervisor do
  @moduledoc """
  Supervisor for the routes repo.
  """

  use Supervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      Routes.Repo
    ]

    children =
      if Application.get_env(:mbta_v3_api, :populate_caches?) do
        children ++
          [
            Routes.PopulateCaches
          ]
      else
        children
      end

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
