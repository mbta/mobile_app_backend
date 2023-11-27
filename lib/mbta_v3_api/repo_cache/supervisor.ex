defmodule RepoCache.Supervisor do
  @moduledoc """
  Supervisor for the repo cache.
  """
  use Supervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      RepoCache.Log
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
