defmodule MBTAV3API.Stream.Supervisor do
  use DynamicSupervisor

  alias MBTAV3API.Stream.Instance

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @type on_start_instance ::
          {:ok, Instance.t()}
          | {:error, {:already_started, Instance.t()} | :max_children | term()}

  @spec start_instance(Instance.opts()) :: on_start_instance()
  def start_instance(args) do
    DynamicSupervisor.start_child(__MODULE__, {MBTAV3API.Stream.Instance, args})
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end