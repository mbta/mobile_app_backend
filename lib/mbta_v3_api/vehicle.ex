defmodule MBTAV3API.Vehicle do
  use MBTAV3API.JsonApi.Object
  require Util

  @type t :: %__MODULE__{
          id: String.t(),
          current_status: current_status(),
          stop_id: String.t() | nil
        }
  Util.declare_enum(
    :current_status,
    Util.enum_values(:uppercase_string, [:incoming_at, :stopped_at, :in_transit_to])
  )

  @derive Jason.Encoder
  defstruct [:id, :current_status, :stop_id, :trip_id]

  @impl JsonApi.Object
  def fields, do: [:current_status]

  @impl JsonApi.Object
  def includes, do: %{stop: MBTAV3API.Stop, trip: MBTAV3API.Trip}

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      current_status: parse_current_status(item.attributes["current_status"]),
      stop_id: JsonApi.Object.get_one_id(item.relationships["stop"]),
      trip_id: JsonApi.Object.get_one_id(item.relationships["trip"])
    }
  end
end
