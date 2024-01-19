defmodule MBTAV3API.Trip do
  alias MBTAV3API.JsonApi

  @behaviour JsonApi.Object

  @type t :: %__MODULE__{id: String.t(), stops: [MBTAV3API.Stop.t()]}

  @derive Jason.Encoder
  defstruct [:id, :stops]

  def fields, do: []

  def includes, do: %{stops: :stop}

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      stops: Enum.map(item.relationships["stops"], &MBTAV3API.Stop.parse/1)
    }
  end
end
