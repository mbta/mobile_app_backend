defmodule MBTAV3API.Trip do
  alias MBTAV3API.JsonApi

  @behaviour JsonApi.Object

  @type t :: %__MODULE__{id: String.t(), stops: [MBTAV3API.Stop.t() | JsonApi.Reference.t()]}

  @derive Jason.Encoder
  defstruct [:id, :stops]

  def fields, do: []

  def includes, do: %{stops: :stop}

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      stops:
        case item.relationships["stops"] do
          nil -> nil
          stops -> Enum.map(stops, &JsonApi.Object.parse/1)
        end
    }
  end
end
