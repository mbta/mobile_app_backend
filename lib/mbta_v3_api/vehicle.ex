defmodule MBTAV3API.Vehicle do
  use MBTAV3API.JsonApi.Object
  require Util
  alias MBTAV3API.Vehicle.Carriage

  @type t :: %__MODULE__{
          id: String.t(),
          bearing: number() | nil,
          carriages: nonempty_list(Carriage.t()) | nil,
          current_status: current_status(),
          current_stop_sequence: integer() | nil,
          direction_id: 0 | 1,
          latitude: float(),
          longitude: float(),
          occupancy_status: occupancy_status(),
          updated_at: DateTime.t(),
          route_id: String.t() | nil,
          stop_id: String.t() | nil,
          trip_id: String.t() | nil,
          decoration: decoration() | nil
        }
  Util.declare_enum(
    :current_status,
    Util.enum_values(:uppercase_string, [:incoming_at, :stopped_at, :in_transit_to]),
    Util.FailOnUnknown
  )

  Util.declare_enum(
    :occupancy_status,
    Util.enum_values(:uppercase_string, [
      :many_seats_available,
      :few_seats_available,
      :standing_room_only,
      :crushed_standing_room_only,
      :full,
      :not_accepting_passengers,
      :no_data_available
    ]),
    :no_data_available
  )

  @type decoration :: :pride | :winter_holiday | :googly_eyes

  @derive Jason.Encoder
  defstruct [
    :id,
    :bearing,
    :carriages,
    :current_status,
    :current_stop_sequence,
    :direction_id,
    :latitude,
    :longitude,
    :occupancy_status,
    :updated_at,
    :route_id,
    :stop_id,
    :trip_id,
    :decoration
  ]

  @impl JsonApi.Object
  def fields do
    [
      :bearing,
      :carriages,
      :current_status,
      :current_stop_sequence,
      :direction_id,
      :latitude,
      :longitude,
      :occupancy_status,
      :updated_at
    ]
  end

  @impl JsonApi.Object
  def includes, do: %{route: MBTAV3API.Route, stop: MBTAV3API.Stop, trip: MBTAV3API.Trip}

  @impl JsonApi.Object
  def virtual_fields, do: [:decoration]

  @spec parse!(JsonApi.Item.t()) :: t()
  def parse!(%JsonApi.Item{} = item) do
    carriages = parse_carriages(item.attributes["carriages"])

    %__MODULE__{
      id: item.id,
      bearing: item.attributes["bearing"],
      carriages: carriages,
      current_status: parse_current_status!(item.attributes["current_status"]),
      current_stop_sequence: item.attributes["current_stop_sequence"],
      direction_id:
        case item.attributes["direction_id"] do
          nil -> raise "vehicle has nil direction_id"
          direction_id -> direction_id
        end,
      latitude: item.attributes["latitude"],
      longitude: item.attributes["longitude"],
      occupancy_status: parse_optional_occupancy(item.attributes["occupancy_status"]),
      updated_at: Util.parse_datetime!(item.attributes["updated_at"]),
      route_id: JsonApi.Object.get_one_id(item.relationships["route"]),
      stop_id: JsonApi.Object.get_one_id(item.relationships["stop"]),
      trip_id: JsonApi.Object.get_one_id(item.relationships["trip"]),
      decoration: parse_decoration(item.id, carriages)
    }
  end

  @spec parse_carriages([map()] | nil) :: nonempty_list(Carriage.t()) | nil
  defp parse_carriages(nil), do: nil
  defp parse_carriages([]), do: nil
  defp parse_carriages(carriages), do: Enum.map(carriages, &Carriage.parse!/1)

  @spec parse_optional_occupancy(String.t() | nil) :: occupancy_status()
  defp parse_optional_occupancy(occupancy_status)
  defp parse_optional_occupancy(nil), do: :no_data_available
  defp parse_optional_occupancy(status), do: parse_occupancy_status(status)

  @spec parse_decoration(String.t(), nonempty_list(Carriage.t()) | nil) :: decoration() | nil
  defp parse_decoration(id, carriages)
  # bus 1833 will always have vehicle ID y1833
  defp parse_decoration("y1833", _), do: :pride
  # CR locomotive 1035 will always have vehicle ID 1035
  defp parse_decoration("1035", _), do: :googly_eyes

  # light rail vehicles will always have vehicle ID G-12345
  defp parse_decoration("G-" <> _, carriages) do
    Enum.find_value(carriages, fn %Carriage{label: label} ->
      cond do
        label == "3706" -> :pride
        label in ["3908", "3917"] -> :winter_holiday
        label in ["3639", "3864", "3909", "3918"] -> :googly_eyes
        true -> nil
      end
    end)
  end

  defp parse_decoration(_, _), do: nil
end
