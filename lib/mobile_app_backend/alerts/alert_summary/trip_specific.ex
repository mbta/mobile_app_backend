defmodule MobileAppBackend.Alerts.AlertSummary.TripSpecific do
  alias MobileAppBackend.Alerts.AlertSummary.Standard
  alias MBTAV3API.Alert
  alias MBTAV3API.Repository
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Schedule
  alias MBTAV3API.Stop
  alias MBTAV3API.Trip
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.GlobalDataCache
  alias Util.PolymorphicJson

  defmodule TripFrom do
    @type t :: %__MODULE__{trip_time: DateTime.t(), stop_name: String.t()}
    @derive PolymorphicJson
    defstruct [:trip_time, :stop_name]
  end

  defmodule TripTo do
    @type t :: %__MODULE__{trip_time: DateTime.t(), headsign: String.t()}
    @derive PolymorphicJson
    defstruct [:trip_time, :headsign]
  end

  defmodule MultipleTrips do
    @type t :: %__MODULE__{}
    @derive PolymorphicJson
    defstruct []
  end

  @type trip_identity :: TripFrom.t() | TripTo.t() | MultipleTrips.t()

  @type t :: %__MODULE__{
          trip_identity: trip_identity(),
          effect: Alert.effect(),
          effect_stops: [String.t()] | nil,
          is_today: boolean(),
          cause: Alert.cause() | nil,
          recurrence: AlertSummary.Recurrence.t() | nil
        }
  @derive PolymorphicJson
  defstruct [:trip_identity, :effect, :effect_stops, :is_today, :cause, :recurrence]

  @spec summary(
          Alert.t(),
          Stop.id(),
          0 | 1,
          [RoutePattern.t()],
          DateTime.t(),
          [Schedule.t()] | nil,
          GlobalDataCache.data()
        ) :: t() | AlertSummary.TripShuttle.t() | nil
  def summary(
        alert,
        stop_id,
        direction_id,
        patterns,
        at_time,
        schedules,
        global
      ) do
    informed_schedules =
      Enum.filter(schedules || [], fn schedule ->
        Enum.any?(alert.informed_entity, &(&1.trip == schedule.trip_id))
      end)

    case alert.effect do
      :shuttle ->
        AlertSummary.TripShuttle.summary(
          alert,
          stop_id,
          direction_id,
          patterns,
          at_time,
          informed_schedules,
          global
        )

      :station_closure ->
        trip_stop_bypass_summary(alert, stop_id, at_time, informed_schedules, global)

      _ ->
        trip_specific_other_summary(alert, stop_id, at_time, informed_schedules, global)
    end
  end

  @doc """
  Combine multiple trip-specific alerts into one. If the stops are all the same,
  combine into one MultiTrip summary. Otherwise, return a standard summary.
  """
  @spec combine(Alert.t(), [t()]) :: t() | Standard.t()
  def combine(alert, summaries) do
    [first | _rest] = summaries

    all_effect_stops =
      summaries
      |> Enum.flat_map(& &1.effect_stops)
      |> MapSet.new()

    same_stops = all_effect_stops == MapSet.new(first.effect_stops)

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
        effect: alert.effect,
        effect_stops: first.effect_stops,
        is_today: first.is_today,
        cause: alert.cause,
        recurrence: first.recurrence
      }
    else
      %AlertSummary.Standard{effect: alert.effect, recurrence: first.recurrence}
    end
  end

  defp trip_stop_bypass_summary(alert, stop_id, at_time, informed_schedules, global) do
    {trip_identity, is_today} =
      case trip_identity_is_today(stop_id, at_time, informed_schedules, global) do
        {%TripFrom{trip_time: trip_time}, is_today} ->
          # must be a single trip since there weren’t multiple trips
          [informed_schedule] = informed_schedules

          case Repository.trips(filter: [id: informed_schedule.trip_id]) do
            {:ok, %{data: [%Trip{headsign: headsign}]}} ->
              {%TripTo{trip_time: trip_time, headsign: headsign}, is_today}

            _ ->
              {nil, nil}
          end

        x ->
          x
      end

    if trip_identity do
      informed_stops =
        alert.informed_entity
        |> Enum.map(& &1.stop)
        |> Enum.map(&global.stops[&1])
        |> Enum.reject(&is_nil/1)
        |> Enum.map(& &1.name)
        |> Enum.uniq()

      %__MODULE__{
        trip_identity: trip_identity,
        effect: alert.effect,
        effect_stops: informed_stops,
        is_today: is_today,
        cause: alert.cause,
        recurrence: AlertSummary.alert_recurrence(alert, at_time)
      }
    end
  end

  defp trip_specific_other_summary(alert, stop_id, at_time, informed_schedules, global) do
    {trip_identity, is_today} =
      trip_identity_is_today(stop_id, at_time, informed_schedules, global)

    if trip_identity != nil do
      %__MODULE__{
        trip_identity: trip_identity,
        effect: alert.effect,
        effect_stops: nil,
        is_today: is_today,
        cause: alert.cause,
        recurrence: AlertSummary.alert_recurrence(alert, at_time)
      }
    end
  end

  defp trip_identity_is_today(stop_id, at_time, informed_schedules, global) do
    case informed_schedules do
      [] ->
        {nil, nil}

      [%Schedule{} = informed_trip]
      when not is_nil(informed_trip.departure_time) or not is_nil(informed_trip.arrival_time) ->
        trip_time = informed_trip.departure_time || informed_trip.arrival_time

        {%TripFrom{
           trip_time: trip_time,
           stop_name: global.stops[stop_id].name
         }, Util.datetime_to_gtfs(trip_time) == Util.datetime_to_gtfs(at_time)}

      _ ->
        {%MultipleTrips{},
         Enum.any?(
           informed_schedules,
           &(Util.datetime_to_gtfs(&1.departure_time || &1.arrival_time) ==
               Util.datetime_to_gtfs(at_time))
         )}
    end
  end
end
