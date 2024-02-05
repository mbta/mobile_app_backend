defmodule MBTAV3API.Trip do
  alias MBTAV3API.JsonApi

  @behaviour JsonApi.Object

  @type t :: %__MODULE__{
          id: String.t(),
          route_pattern: MBTAV3API.RoutePattern.t() | JsonApi.Reference.t() | nil,
          stops: [MBTAV3API.Stop.t() | JsonApi.Reference.t()] | nil
        }

  @derive Jason.Encoder
  defstruct [:id, :route_pattern, :stops]

  def fields, do: []

  def includes, do: %{route_pattern: :route_pattern, stops: :stop}

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      route_pattern: JsonApi.Object.parse_one_related(item.relationships["route_pattern"]),
      stops: JsonApi.Object.parse_many_related(item.relationships["stops"])
    }
  end
end
