defmodule MobileAppBackend.Alerts.AlertSummary.TripShuttle do
  alias MBTAV3API.Alert
  alias MBTAV3API.Route
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Schedule
  alias MBTAV3API.Stop
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Alerts.AlertSummary.Standard
  alias MobileAppBackend.GlobalDataCache
  alias Util.PolymorphicJson

  defmodule SingleTrip do
    @type t :: %__MODULE__{
            trip_time: DateTime.t(),
            route_type: Route.type(),
            from_stop_name: String.t() | nil
          }
    @derive PolymorphicJson
    defstruct [:trip_time, :route_type, :from_stop_name]
  end

  defmodule ThisTrip do
    @type t :: %__MODULE__{route_type: Route.type()}
    @derive PolymorphicJson
    defstruct [:route_type]
  end

  defmodule MultipleTrips do
    @type t :: %__MODULE__{}
    @derive PolymorphicJson
    defstruct []
  end

  @type trip_identity :: SingleTrip.t() | ThisTrip.t() | MultipleTrips.t()

  @type t :: %__MODULE__{
          trip_identity: trip_identity(),
          start_stop_name: String.t(),
          end_stop_name: String.t(),
          recurrence: AlertSummary.Recurrence.t() | nil
        }
  @derive PolymorphicJson
  defstruct [
    :trip_identity,
    :start_stop_name,
    :end_stop_name,
    :recurrence
  ]

  @spec summary(
          Alert.t(),
          Stop.id(),
          0 | 1,
          [RoutePattern.t()],
          DateTime.t(),
          [Schedule.t()] | nil,
          GlobalDataCache.data()
        ) :: t() | nil
  def summary(
        alert,
        stop_id,
        direction_id,
        patterns,
        at_time,
        informed_schedules,
        global
      ) do
    with %AlertSummary.Location.SuccessiveStops{
           start_stop_name: location_start_stop_name,
           end_stop_name: end_stop_name,
           downstream: downstream
         } <-
           AlertSummary.alert_location(alert, stop_id, direction_id, patterns, global),
         %Stop{name: current_stop_name} <- global.stops[stop_id],
         start_stop_name <-
           resolve_start_stop_name(downstream, location_start_stop_name, current_stop_name),
         identity_stop_name <- resolve_trip_identity_stop_name(downstream, current_stop_name),
         trip_identity when not is_nil(trip_identity) <-
           trip_identity(identity_stop_name, patterns, informed_schedules, global) do
      %__MODULE__{
        trip_identity: trip_identity,
        start_stop_name: start_stop_name,
        end_stop_name: end_stop_name,
        recurrence: AlertSummary.alert_recurrence(alert, at_time)
      }
    else
      _ -> nil
    end
  end

  defp resolve_start_stop_name(downstream, location_start_stop_name, current_stop_name) do
    case downstream do
      false -> current_stop_name
      _ -> location_start_stop_name
    end
  end

  defp resolve_trip_identity_stop_name(downstream, current_stop_name) do
    case downstream do
      false -> nil
      _ -> current_stop_name
    end
  end

  @doc """
  Combine multiple trip-shuttle alerts into one.
  If the current & end stops are the same, combine
  into one MultiTrip summary. Otherwise, return a standard summary.
  """
  @spec combine(Alert.t(), [t()]) :: t() | Standard.t()
  def combine(alert, summaries) do
    [first | _rest] = summaries

    same_stops =
      summaries
      |> Enum.flat_map(&[&1.start_stop_name, &1.end_stop_name])
      |> MapSet.new()
      |> MapSet.size() == 2

    if same_stops do
      same_trip_id =
        summaries
        |> Enum.map(& &1.trip_identity)
        |> Enum.uniq()
        |> Enum.count() == 1

      trip_identity =
        if same_trip_id do
          first.trip_identity
        else
          %__MODULE__.MultipleTrips{}
        end

      %__MODULE__{
        trip_identity: trip_identity,
        start_stop_name: first.start_stop_name,
        end_stop_name: first.end_stop_name,
        recurrence: first.recurrence
      }
    else
      %AlertSummary.Standard{effect: alert.effect, recurrence: first.recurrence}
    end
  end

  defp trip_identity(
         current_stop_name,
         patterns,
         informed_schedules,
         global
       ) do
    case informed_schedules do
      [] ->
        nil

      [%Schedule{} = informed_trip]
      when not is_nil(informed_trip.departure_time) or not is_nil(informed_trip.arrival_time) ->
        trip_time = informed_trip.departure_time || informed_trip.arrival_time

        case Enum.find_value(patterns, &global.routes[&1.route_id]) do
          %Route{type: route_type} ->
            %SingleTrip{
              trip_time: trip_time,
              route_type: route_type,
              from_stop_name: current_stop_name
            }

          _ ->
            nil
        end

      _ ->
        %MultipleTrips{}
    end
  end
end
