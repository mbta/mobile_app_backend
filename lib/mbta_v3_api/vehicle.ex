defmodule MBTAV3API.Vehicle do
  use MBTAV3API.JsonApi.Object
  require Util

  @type t :: %__MODULE__{
          id: String.t(),
          current_status: current_status(),
          stop: MBTAV3API.Stop.t() | JsonApi.Reference.t() | nil
        }
  Util.declare_enum(
    :current_status,
    Util.enum_values(:uppercase_string, [:incoming_at, :stopped_at, :in_transit_to])
  )

  @derive Jason.Encoder
  defstruct [:id, :current_status, :stop]

  @impl JsonApi.Object
  def fields, do: [:current_status]

  @impl JsonApi.Object
  def includes, do: %{stop: :stop}

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      current_status: parse_current_status(item.attributes["current_status"]),
      stop: JsonApi.Object.parse_one_related(item.relationships["stop"])
    }
  end
end
