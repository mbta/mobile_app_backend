defmodule MBTAV3API.JsonApi.Response do
  alias MBTAV3API.JsonApi

  defdelegate to_full_map(objects), to: JsonApi.Object

  @type t(data) :: %__MODULE__{data: [data], included: JsonApi.Object.full_map()}

  defstruct [:data, included: JsonApi.Object.to_full_map([])]

  @doc """
  Parses everything in a `t:JsonApi.t/0`, discarding objects which cannot be parsed.
  """
  @spec parse(JsonApi.t()) :: t(JsonApi.Object.t())
  def parse(%JsonApi{data: data, included: included}) do
    %__MODULE__{
      data: JsonApi.Object.parse_all_discarding_failures(data, included),
      included:
        included |> JsonApi.Object.parse_all_discarding_failures(included) |> to_full_map()
    }
  end
end
