defmodule MBTAV3API.RoutePattern do
  alias MBTAV3API.Trip
  use MBTAV3API.JsonApi.Object
  require Util

  @type t :: %__MODULE__{
          id: String.t(),
          direction_id: 0 | 1,
          name: String.t(),
          sort_order: integer(),
          typicality: typicality(),
          representative_trip_id: String.t(),
          route_id: String.t()
        }

  @typedoc """
  Denotes how common a route pattern is.

  Deviations are usually more common than atypical patterns.
  Atypical patterns generally run at specific times, like in early mornings or on school days.
  Diversions include planned detours, bus shuttles, and snow routes.
  Canonical-only patterns are, at least in theory, not scheduled to take place at any time.

  See the `route_pattern_typicality` docs in the [MBTA GTFS documentation](https://github.com/mbta/gtfs-documentation/blob/7146d103ba0d3894b17f34175abc78ac2a925bd7/reference/gtfs.md#route_patternstxt).
  """
  Util.declare_enum(
    :typicality,
    Util.enum_values(:index, [nil, :typical, :deviation, :atypical, :diversion, :canonical_only])
  )

  @derive Jason.Encoder
  defstruct [
    :id,
    :direction_id,
    :name,
    :sort_order,
    :typicality,
    :representative_trip_id,
    :route_id
  ]

  @impl JsonApi.Object
  def fields, do: [:direction_id, :name, :sort_order, :typicality]

  @impl JsonApi.Object
  def includes, do: %{representative_trip: MBTAV3API.Trip, route: MBTAV3API.Route}

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      direction_id: item.attributes["direction_id"],
      name: item.attributes["name"],
      sort_order: item.attributes["sort_order"],
      typicality: parse_typicality(item.attributes["typicality"]),
      representative_trip_id:
        JsonApi.Object.get_one_id(item.relationships["representative_trip"]),
      route_id: JsonApi.Object.get_one_id(item.relationships["route"])
    }
  end

  @spec get_pattern_ids_by_stop([t()], JsonApi.Object.trip_map(), MapSet.t(String.t()) | nil) ::
          %{String.t() => [String.t()]}
  def get_pattern_ids_by_stop(route_patterns, trips, filter_stop_ids \\ nil) do
    route_patterns
    |> Enum.flat_map(fn
      %__MODULE__{
        id: route_pattern_id,
        representative_trip_id: trip_id
      } ->
        %Trip{stop_ids: trip_stop_ids} = trips[trip_id]

        trip_stop_ids
        |> Enum.filter(&(filter_stop_ids == nil || MapSet.member?(filter_stop_ids, &1)))
        |> Enum.map(&%{stop_id: &1, route_pattern_id: route_pattern_id})
    end)
    |> Enum.group_by(& &1.stop_id, & &1.route_pattern_id)
  end

  @spec get_route_map([t()]) :: %{String.t() => MBTAV3API.Route.t()}
  def get_route_map(route_patterns) do
    route_patterns
    |> Enum.map(& &1.route)
    |> Map.new(&{&1.id, &1})
  end
end
