defmodule MBTAV3API.Stream.Registry do
  def child_spec(_) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  def via_name(key), do: {:via, Registry, {__MODULE__, key}}
end
