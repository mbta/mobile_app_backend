defmodule MBTAV3API.Alert do
  use MBTAV3API.JsonApi.Object
  require Util
  alias MBTAV3API.Alert.ActivePeriod
  alias MBTAV3API.Alert.InformedEntity

  @type t :: %__MODULE__{
          id: String.t(),
          active_period: [ActivePeriod.t()],
          cause: cause(),
          description: String.t() | nil,
          effect: effect(),
          effect_name: String.t() | nil,
          header: String.t() | nil,
          informed_entity: [InformedEntity.t()],
          lifecycle: lifecycle(),
          updated_at: DateTime.t()
        }

  Util.declare_enum(
    :cause,
    Util.enum_values(:uppercase_string, [
      :accident,
      :amtrak,
      :an_earlier_mechanical_problem,
      :an_earlier_signal_problem,
      :autos_impeding_service,
      :coast_guard_restriction,
      :congestion,
      :construction,
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
      :mechanical_problem,
      :medical_emergency,
      :other_cause,
      :parade,
      :police_action,
      :police_activity,
      :power_problem,
      :severe_weather,
      :signal_problem,
      :slippery_rail,
      :snow,
      :special_event,
      :speed_restriction,
      :strike,
      :switch_problem,
      :technical_problem,
      :tie_replacement,
      :track_problem,
      :track_work,
      :traffic,
      :unruly_passenger,
      :unknown_cause,
      :weather
    ]),
    :unknown_cause
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
    :description,
    :effect,
    :effect_name,
    :header,
    :informed_entity,
    :lifecycle,
    :updated_at
  ]

  @impl JsonApi.Object
  def fields do
    [
      :active_period,
      :cause,
      :description,
      :effect,
      :effect_name,
      :header,
      :informed_entity,
      :lifecycle,
      :updated_at
    ]
  end

  @impl JsonApi.Object
  def includes, do: %{}

  @impl JsonApi.Object
  def serialize_filter_value(:activity, value), do: InformedEntity.serialize_activity!(value)
  def serialize_filter_value(:lifecycle, value), do: serialize_lifecycle!(value)
  def serialize_filter_value(_field, value), do: value

  @spec active?(t(), DateTime.t()) :: boolean()
  def active?(alert, now \\ DateTime.now!("America/New_York")) do
    Enum.any?(alert.active_period, fn %ActivePeriod{start: ap_start, end: ap_end} ->
      cond do
        DateTime.compare(now, ap_start) == :lt -> false
        is_nil(ap_end) -> true
        DateTime.compare(now, ap_end) == :gt -> false
        true -> true
      end
    end)
  end

  @spec parse!(JsonApi.Item.t()) :: t()
  def parse!(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      active_period: Enum.map(item.attributes["active_period"], &ActivePeriod.parse!/1),
      cause: parse_cause(item.attributes["cause"]),
      description: item.attributes["description"],
      effect: parse_effect(item.attributes["effect"]),
      effect_name: item.attributes["effect_name"],
      header: item.attributes["header"],
      informed_entity: Enum.map(item.attributes["informed_entity"], &InformedEntity.parse!/1),
      lifecycle: parse_lifecycle!(item.attributes["lifecycle"]),
      updated_at: Util.parse_datetime!(item.attributes["updated_at"])
    }
  end
end
