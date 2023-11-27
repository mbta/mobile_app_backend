defmodule MBTAV3API.Supervisor do
  @moduledoc """
  Start the supervision tree for the MBTAV3API.
  """
  use Supervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      RepoCache.Supervisor,
      Routes.Supervisor,
      MBTAV3API.Cache
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
