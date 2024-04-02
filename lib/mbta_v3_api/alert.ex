defmodule MBTAV3API.Alert do
  alias MBTAV3API.Route
  use MBTAV3API.JsonApi.Object
  require Util
  alias MBTAV3API.Alert.ActivePeriod
  alias MBTAV3API.Alert.InformedEntity

  @type t :: %__MODULE__{
          id: String.t(),
          active_period: [ActivePeriod.t()],
          effect: effect(),
          effect_name: String.t() | nil,
          informed_entity: [InformedEntity.t()],
          lifecycle: lifecycle()
        }

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
      :summary,
      :suspension,
      :track_change,
      :unknown_effect
    ])
  )

  Util.declare_enum(
    :lifecycle,
    Util.enum_values(:uppercase_string, [:new, :ongoing, :ongoing_upcoming, :upcoming])
  )

  @derive Jason.Encoder
  defstruct [:id, :active_period, :effect, :effect_name, :informed_entity, :lifecycle]

  @impl JsonApi.Object
  def fields, do: [:active_period, :effect, :effect_name, :informed_entity, :lifecycle]

  @impl JsonApi.Object
  def includes, do: %{}

  @impl JsonApi.Object
  def serialize_filter_value(:activity, value), do: InformedEntity.serialize_activity(value)
  def serialize_filter_value(:lifecycle, value), do: serialize_lifecycle(value)
  def serialize_filter_value(:route_type, value), do: Route.serialize_type(value)
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

  @spec by_route_and_stop([t()]) :: %{Route.id() => %{Stop.id() => [t()]}}
  @doc """
  A nested map of alerts by route_id an stop_id.
  """
  def by_route_and_stop(alerts) do
    alerts
    |> Enum.flat_map(fn alert ->
      Enum.map(alert.informed_entity, &{&1.route, &1.stop, alert})
    end)
    |> Enum.group_by(fn {route_id, _stop_id, _alert} -> route_id end, fn {_route_id, stop_id,
                                                                          alert} ->
      {stop_id, alert}
    end)
    |> Map.new(fn {route_id, stop_alerts} ->
      {route_id, Enum.group_by(stop_alerts, &elem(&1, 0), &elem(&1, 1))}
    end)
  end

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      active_period: Enum.map(item.attributes["active_period"], &ActivePeriod.parse/1),
      effect: parse_effect(item.attributes["effect"]),
      effect_name: item.attributes["effect_name"],
      informed_entity: Enum.map(item.attributes["informed_entity"], &InformedEntity.parse/1),
      lifecycle: parse_lifecycle(item.attributes["lifecycle"])
    }
  end
end
