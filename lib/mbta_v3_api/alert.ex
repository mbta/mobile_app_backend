defmodule MBTAV3API.Alert do
  use MBTAV3API.JsonApi.Object
  require Util
  alias MBTAV3API.Alert.ActivePeriod
  alias MBTAV3API.Alert.InformedEntity
  alias MBTAV3API.Route
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stop
  alias MBTAV3API.Trip

  @type t :: %__MODULE__{
          id: String.t(),
          active_period: [ActivePeriod.t()],
          cause: cause(),
          closed_timestamp: DateTime.t() | nil,
          description: String.t() | nil,
          duration_certainty: duration_certainty(),
          effect: effect(),
          effect_name: String.t() | nil,
          header: String.t() | nil,
          informed_entity: [InformedEntity.t()],
          last_push_notification_timestamp: DateTime.t() | nil,
          lifecycle: lifecycle(),
          severity: integer(),
          updated_at: DateTime.t()
        }

  Util.declare_enum(
    :cause,
    Util.enum_values(:uppercase_string, [
      :accident,
      :amtrak,
      :amtrak_train_traffic,
      :an_earlier_mechanical_problem,
      :an_earlier_signal_problem,
      :autos_impeding_service,
      :coast_guard_restriction,
      :congestion,
      :construction,
      :crossing_issue,
      :crossing_malfunction,
      :demonstration,
      :disabled_bus,
      :disabled_train,
      :drawbridge_being_raised,
      :electrical_work,
      :fire,
      :fire_department_activity,
      :flooding,
      :fog,
      :freight_train_interference,
      :hazmat_condition,
      :heavy_ridership,
      :high_winds,
      :holiday,
      :hurricane,
      :ice_in_harbor,
      :maintenance,
      :mechanical_issue,
      :mechanical_problem,
      :medical_emergency,
      :other_cause,
      :parade,
      :police_action,
      :police_activity,
      :power_problem,
      :rail_defect,
      :severe_weather,
      :signal_issue,
      :signal_problem,
      :single_tracking,
      :slippery_rail,
      :snow,
      :special_event,
      :speed_restriction,
      :strike,
      :switch_issue,
      :switch_problem,
      :technical_problem,
      :tie_replacement,
      :track_problem,
      :track_work,
      :traffic,
      :train_traffic,
      :unruly_passenger,
      :unknown_cause,
      :weather
    ]),
    :unknown_cause
  )

  Util.declare_enum(
    :duration_certainty,
    Util.enum_values(:uppercase_string, [:estimated, :known, :unknown]),
    :unknown
  )

  Util.declare_enum(
    :effect,
    Util.enum_values(:uppercase_string, [
      :access_issue,
      :additional_service,
      :amber_alert,
      :bike_issue,
      :cancellation,
      :delay,
      :detour,
      :dock_closure,
      :dock_issue,
      :elevator_closure,
      :escalator_closure,
      :extra_service,
      :facility_issue,
      :modified_service,
      :no_service,
      :other_effect,
      :parking_closure,
      :parking_issue,
      :policy_change,
      :schedule_change,
      :service_change,
      :shuttle,
      :snow_route,
      :station_closure,
      :station_issue,
      :stop_closure,
      :stop_move,
      :stop_moved,
      :stop_shoveling,
      :summary,
      :suspension,
      :track_change,
      :unknown_effect
    ]),
    :unknown_effect
  )

  Util.declare_enum(
    :lifecycle,
    Util.enum_values(:uppercase_string, [:new, :ongoing, :ongoing_upcoming, :upcoming]),
    Util.FailOnUnknown
  )

  @derive Jason.Encoder
  defstruct [
    :id,
    :active_period,
    :cause,
    :closed_timestamp,
    :description,
    :duration_certainty,
    :effect,
    :effect_name,
    :header,
    :informed_entity,
    :last_push_notification_timestamp,
    :lifecycle,
    :severity,
    :updated_at
  ]

  @impl JsonApi.Object
  def fields do
    [
      :active_period,
      :cause,
      :closed_timestamp,
      :description,
      :duration_certainty,
      :effect,
      :effect_name,
      :header,
      :informed_entity,
      :last_push_notification_timestamp,
      :lifecycle,
      :severity,
      :updated_at
    ]
  end

  @impl JsonApi.Object
  def includes, do: %{}

  @impl JsonApi.Object
  def serialize_filter_value(:activity, value), do: InformedEntity.serialize_activity!(value)
  def serialize_filter_value(:lifecycle, value), do: serialize_lifecycle!(value)
  def serialize_filter_value(_field, value), do: value

  @spec current_period(t(), DateTime.t()) :: ActivePeriod.t() | nil
  def current_period(alert, now) do
    Enum.find(alert.active_period, fn %ActivePeriod{start: ap_start, end: ap_end} ->
      cond do
        DateTime.compare(now, ap_start) == :lt -> false
        is_nil(ap_end) -> true
        DateTime.compare(now, ap_end) == :gt -> false
        true -> true
      end
    end)
  end

  @spec next_period(t(), DateTime.t()) :: ActivePeriod.t() | nil
  def next_period(alert, now) do
    Enum.find(alert.active_period, fn %ActivePeriod{start: ap_start} ->
      hours_in_future = DateTime.diff(ap_start, now, :hour)
      hours_in_future > 0 and hours_in_future < 24
    end)
  end

  @spec active?(t(), DateTime.t()) :: boolean()
  def active?(alert, now \\ DateTime.now!("America/New_York")) do
    current_period(alert, now) != nil
  end

  @spec active_soon?(t(), DateTime.t()) :: boolean()
  def active_soon?(alert, now \\ DateTime.now!("America/New_York")) do
    next_period(alert, now) != nil
  end

  @spec parse!(JsonApi.Item.t()) :: t()
  def parse!(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      active_period:
        Enum.map(item.attributes["active_period"], &ActivePeriod.parse!/1)
        |> ActivePeriod.collapse(),
      cause: parse_cause(item.attributes["cause"]),
      closed_timestamp: Util.parse_optional_datetime!(item.attributes["closed_timestamp"]),
      description: item.attributes["description"],
      duration_certainty: parse_duration_certainty(item.attributes["duration_certainty"]),
      effect: parse_effect(item.attributes["effect"]),
      effect_name: item.attributes["effect_name"],
      header: item.attributes["header"],
      informed_entity: Enum.map(item.attributes["informed_entity"], &InformedEntity.parse!/1),
      last_push_notification_timestamp:
        Util.parse_optional_datetime!(item.attributes["last_push_notification_timestamp"]),
      lifecycle: parse_lifecycle!(item.attributes["lifecycle"]),
      severity: item.attributes["severity"],
      updated_at: Util.parse_datetime!(item.attributes["updated_at"])
    }
  end

  @doc """
  These are newly added causes that were not included in the initial release, we filter them out of the original
  alert channel so users who haven't upgraded the app don't get crashes when an alert contains one.
  Any clients using the v2 alert channel also have handling for unknown cause and effect types, so any future
  causes can be added here as well.
  """
  @spec v2_causes :: MapSet.t(cause())
  def v2_causes do
    MapSet.new([
      :amtrak_train_traffic,
      :crossing_issue,
      :mechanical_issue,
      :rail_defect,
      :signal_issue,
      :single_tracking,
      :switch_issue,
      :train_traffic
    ])
  end

  @spec has_stops_specified(t()) :: boolean()
  def has_stops_specified(alert) do
    Enum.all?(alert.informed_entity, &(&1.stop != nil))
  end

  @type significance :: :major | :secondary | :accessibility | :minor | nil

  @spec significance(t(), DateTime.t() | nil) :: significance()
  def significance(alert, at_time) do
    intrinsic_significance = intrinsic_significance(alert)

    max_significance =
      cond do
        # active now or checking intrinsic significance, use intrinsic
        is_nil(at_time) or active?(alert, at_time) ->
          :major

        # upcoming, show as secondary if will be major later
        active_soon?(alert, at_time) ->
          :secondary

        # all clear, hide completely until we have implemented the summary template
        Enum.all?(
          alert.active_period,
          &(not is_nil(&1.end) and DateTime.before?(&1.end, at_time))
        ) ->
          nil

        # will be active later but not soon enough to show yet, hide completely
        true ->
          nil
      end

    Enum.min([intrinsic_significance, max_significance], &(compare_significance(&1, &2) != :gt))
  end

  defp intrinsic_significance(alert)

  defp intrinsic_significance(%__MODULE__{effect: e}) when e in [:shuttle, :suspension],
    do: :major

  defp intrinsic_significance(%__MODULE__{effect: e} = alert)
       when e in [:station_closure, :stop_closure, :dock_closure, :detour, :snow_route] do
    if has_stops_specified(alert) do
      :major
    else
      :secondary
    end
  end

  defp intrinsic_significance(%__MODULE__{effect: :service_change}), do: :secondary
  defp intrinsic_significance(%__MODULE__{effect: :elevator_closure}), do: :accessibility
  defp intrinsic_significance(%__MODULE__{effect: :track_change}), do: :minor

  defp intrinsic_significance(%__MODULE__{effect: :delay} = alert) do
    if (alert.severity >= 3 and Enum.any?(alert.informed_entity, &(&1.route_type != :bus))) or
         alert.cause == :single_tracking do
      :minor
    else
      nil
    end
  end

  # in the frontend, we ignore cancellation alerts, since we show trips as cancelled directly,
  # but in the backend, we still want to treat them as significant enough to be sent
  defp intrinsic_significance(%__MODULE__{effect: :cancellation}), do: :secondary

  defp intrinsic_significance(_), do: nil

  @spec compare_significance(significance(), significance()) :: :lt | :eq | :gt
  def compare_significance(s1, s2) do
    significance_numbers = %{major: 5, secondary: 4, accessibility: 3, minor: 2, nil: 1}
    n1 = significance_numbers[s1]
    n2 = significance_numbers[s2]

    cond do
      n1 < n2 -> :lt
      n1 == n2 -> :eq
      n1 > n2 -> :gt
    end
  end

  @spec any_informed_entity_satisfies(t(), (InformedEntity.t() -> boolean())) :: boolean()
  def any_informed_entity_satisfies(alert, predicate) do
    Enum.any?(alert.informed_entity, predicate)
  end

  defmodule RecurrenceInfo do
    @type t :: %__MODULE__{
            start: DateTime.t(),
            end: DateTime.t(),
            days: MapSet.t(Calendar.day_of_week())
          }
    defstruct [:start, :end, :days]

    @spec daily(t()) :: boolean()
    def daily(%__MODULE__{days: days}), do: MapSet.size(days) == 7
  end

  @spec recurrence_range(t()) :: RecurrenceInfo.t() | nil
  def recurrence_range(%__MODULE__{} = alert) do
    with num_periods when num_periods > 1 <- length(alert.active_period),
         first_period <- Enum.min_by(alert.active_period, & &1.start, DateTime),
         last_period <- Enum.max_by(alert.active_period, & &1.end, DateTime),
         true <-
           Enum.all?(alert.active_period, fn %ActivePeriod{} = ap ->
             Util.datetime_to_gtfs(ap.start) ==
               Util.datetime_to_gtfs(ap.end, rounding: :backwards) and
               DateTime.to_time(ap.start) == DateTime.to_time(first_period.start) and
               DateTime.to_time(ap.end) == DateTime.to_time(last_period.end)
           end) do
      alert_days = Enum.map(alert.active_period, &Util.datetime_to_gtfs(&1.start))

      all_alert_days_contiguous? =
        alert_days
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.all?(fn [a, b] -> Date.diff(b, a) == 1 end)

      days =
        if all_alert_days_contiguous? do
          MapSet.new(1..7)
        else
          MapSet.new(alert_days, &Date.day_of_week/1)
        end

      %RecurrenceInfo{start: first_period.start, end: last_period.end, days: days}
    else
      _ -> nil
    end
  end

  @spec applicable_alerts([t()], 0 | 1 | nil, [Route.id()], [Stop.id()] | nil, Trip.id() | nil) ::
          [t()]
  def applicable_alerts(alerts, direction_id, route_ids, stop_ids, trip_id) do
    Enum.filter(alerts, fn alert ->
      any_informed_entity_satisfies(alert, fn ie ->
        InformedEntity.activity_in?(ie, [:board]) and
          InformedEntity.direction?(ie, direction_id) and
          InformedEntity.route_in?(ie, route_ids) and
          (is_nil(stop_ids) or InformedEntity.stop_in?(ie, stop_ids)) and
          InformedEntity.trip?(ie, trip_id)
      end)
    end)
  end

  @spec elevator_alerts([t()], [Stop.id()]) :: [t()]
  def elevator_alerts(alerts, stop_ids) do
    Enum.filter(alerts, fn alert ->
      alert.effect == :elevator_closure and
        any_informed_entity_satisfies(alert, fn ie ->
          InformedEntity.activity_in?(ie, [:using_wheelchair]) and
            InformedEntity.stop_in?(ie, stop_ids)
        end)
    end)
  end

  @spec downstream_alerts([t()], Trip.t(), [Stop.id()]) :: [t()]
  def downstream_alerts(alerts, trip, target_stop_with_children) do
    stop_ids = trip.stop_ids || []

    alerts =
      Enum.filter(
        alerts,
        &(has_stops_specified(&1) and
            compare_significance(significance(&1, nil), :accessibility) != :lt)
      )

    target_stop_alert_ids =
      alerts
      |> Enum.filter(fn alert ->
        any_informed_entity_satisfies(
          alert,
          &applies_downstream_at(&1, trip, target_stop_with_children)
        )
      end)
      |> MapSet.new(& &1.id)

    downstream_stops =
      stop_ids |> Enum.drop_while(&(&1 not in target_stop_with_children)) |> Enum.drop(1)

    Enum.find_value(downstream_stops, [], fn stop ->
      alerts
      |> Enum.filter(fn alert ->
        any_informed_entity_satisfies(alert, &applies_downstream_at(&1, trip, [stop])) and
          alert.id not in target_stop_alert_ids
      end)
      |> case do
        [] -> nil
        downstream_alerts -> downstream_alerts
      end
    end)
  end

  defp applies_downstream_at(ie, trip, stop_ids) do
    InformedEntity.activity_in?(ie, [:exit, :ride]) and
      InformedEntity.direction?(ie, trip.direction_id) and
      InformedEntity.route?(ie, trip.route_id) and
      InformedEntity.stop_in?(ie, stop_ids)
  end

  @spec alerts_downstream_for_patterns([t()], [RoutePattern.t()], [Stop.id()], %{
          Trip.id() => Trip.t()
        }) :: [t()]
  def alerts_downstream_for_patterns(alerts, patterns, target_stop_with_children, trips_by_id) do
    patterns
    |> Enum.flat_map(fn pattern ->
      if trip = trips_by_id[pattern.representative_trip_id] do
        downstream_alerts(alerts, trip, target_stop_with_children)
      else
        []
      end
    end)
    |> Enum.uniq()
  end
end
