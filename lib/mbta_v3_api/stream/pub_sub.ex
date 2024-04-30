defmodule MBTAV3API.Stream.PubSub do
  def child_spec(_) do
    Phoenix.PubSub.child_spec(name: __MODULE__)
  end

  @spec broadcast!(Phoenix.PubSub.topic(), Phoenix.PubSub.message()) :: :ok
  def broadcast!(topic, message), do: Phoenix.PubSub.broadcast!(__MODULE__, topic, message)

  @spec subscribe(Phoenix.PubSub.topic()) :: :ok | {:error, term()}
  def subscribe(topic), do: Phoenix.PubSub.subscribe(__MODULE__, topic)
end
