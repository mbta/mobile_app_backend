defmodule MobileAppBackend.Alerts.AlertWithSummaries do
  alias MBTAV3API.Alert
  alias MBTAV3API.Alert.ActivePeriod
  alias MBTAV3API.Alert.InformedEntity
  alias MobileAppBackend.Alerts.SummaryEntity

  @type t :: %__MODULE__{
          id: String.t(),
          active_period: [ActivePeriod.t()],
          cause: Alert.cause(),
          closed_timestamp: DateTime.t() | nil,
          description: String.t() | nil,
          duration_certainty: Alert.duration_certainty(),
          effect: Alert.effect(),
          effect_name: String.t() | nil,
          header: String.t() | nil,
          informed_entity: [InformedEntity.t()],
          last_push_notification_timestamp: DateTime.t() | nil,
          lifecycle: Alert.lifecycle(),
          severity: integer(),
          summaries: [SummaryEntity.t()],
          summaries_updated_at: DateTime.t(),
          updated_at: DateTime.t()
        }

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
    :summaries,
    :summaries_updated_at,
    :updated_at
  ]

  @spec from_alert(Alert.t(), [SummaryEntity.t()]) :: t()
  def from_alert(alert, summaries, summaries_updated_at \\ DateTime.now!("America/New_York")) do
    struct(
      %__MODULE__{summaries: summaries, summaries_updated_at: summaries_updated_at},
      Map.from_struct(alert)
    )
  end

  @doc """
  Alert summaries should be recalculated if any of the following are true:
  - The alert has changed (e.g. description, header, effect, etc.)
  - The alert has changed from active to inactive or vice versa
  - It is a different day than the last time summaries were calculated (either calendar date or service date)
  """
  def should_recalculate_summaries?(
        old_alert_with_summaries,
        new_alert,
        now \\ DateTime.now!("America/New_York")
      ) do
    old_alert = struct(Alert, Map.from_struct(old_alert_with_summaries))

    old_alert != new_alert ||
      Alert.active?(old_alert, old_alert_with_summaries.summaries_updated_at) !=
        Alert.active?(new_alert, now) ||
      DateTime.to_date(old_alert_with_summaries.summaries_updated_at) !=
        DateTime.to_date(now) ||
      Util.DateTime.datetime_to_gtfs(old_alert_with_summaries.summaries_updated_at) !=
        Util.DateTime.datetime_to_gtfs(now)
  end
end
