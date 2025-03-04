defmodule MobileAppBackend.Alerts.Registry do
  def child_spec(_) do
    Registry.child_spec(keys: :duplicate, name: __MODULE__)
  end

  @spec via_name(term()) :: GenServer.name()
  def via_name(key), do: {:via, Registry, {__MODULE__, key}}

  @spec find_pid(term()) :: pid() | nil
  def find_pid(key) do
    case Registry.lookup(__MODULE__, key) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end
end
