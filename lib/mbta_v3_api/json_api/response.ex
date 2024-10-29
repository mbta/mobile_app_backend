defmodule MBTAV3API.JsonApi.Response do
  alias MBTAV3API.JsonApi

  defdelegate to_full_map(objects), to: JsonApi.Object

  @type t(data) :: %__MODULE__{data: [data], included: JsonApi.Object.full_map()}

  defstruct [:data, included: JsonApi.Object.to_full_map([])]

  @doc """
  Parses everything in a `t:JsonApi.t/0`.
  """
  @spec parse(JsonApi.t()) :: t(JsonApi.Object.t())
  def parse(%JsonApi{data: data, included: included}) do
    %__MODULE__{
      data: Enum.map(data, &JsonApi.Object.parse(&1, included)),
      included: included |> Enum.map(&JsonApi.Object.parse(&1, included)) |> to_full_map()
    }
  end
end
