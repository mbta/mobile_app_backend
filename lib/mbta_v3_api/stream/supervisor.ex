defmodule MBTAV3API.Stream.Supervisor do
  use DynamicSupervisor

  require Logger
  alias MBTAV3API.Stream.Instance

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @type on_start_instance ::
          {:ok, Instance.t()}
          | {:error, {:already_started, Instance.t()} | :max_children | term()}

  @spec start_instance(Instance.opts()) :: on_start_instance()
  def start_instance(args) do
    {:ok, _pid} = DynamicSupervisor.start_child(__MODULE__, {MBTAV3API.Stream.Instance, args})
  end

  @spec start_static_instance(Instance.opts()) :: on_start_instance()
  def start_static_instance(args) do
    {:ok, _pid} =
      DynamicSupervisor.start_child(__MODULE__, MBTAV3API.Stream.StaticInstance.child_spec(args))
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def log_health do
    instances = DynamicSupervisor.which_children(__MODULE__)

    for {_, instance, _, _} <- instances do
      MBTAV3API.Stream.Instance.check_health(instance)
    end

    :ok
  end
end
