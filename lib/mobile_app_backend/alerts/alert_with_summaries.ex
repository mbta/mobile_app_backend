defmodule MobileAppBackend.Alerts.AlertWithSummaries do
  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.SummaryEntity

  @type t :: %__MODULE__{
          alert: Alert.t(),
          summaries: [SummaryEntity.t()],
          summaries_updated_at: DateTime.t()
        }

  @derive Jason.Encoder
  defstruct [
    :alert,
    :summaries,
    :summaries_updated_at
  ]

  @spec from_alert(Alert.t(), [SummaryEntity.t()]) :: t()
  def from_alert(alert, summaries, summaries_updated_at \\ DateTime.now!("America/New_York")) do
    %__MODULE__{alert: alert, summaries: summaries, summaries_updated_at: summaries_updated_at}
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
    old_alert = old_alert_with_summaries.alert

    old_alert != new_alert ||
      Alert.active?(old_alert, old_alert_with_summaries.summaries_updated_at) !=
        Alert.active?(new_alert, now) ||
      DateTime.to_date(old_alert_with_summaries.summaries_updated_at) !=
        DateTime.to_date(now) ||
      Util.DateTime.datetime_to_gtfs(old_alert_with_summaries.summaries_updated_at) !=
        Util.DateTime.datetime_to_gtfs(now)
  end
end
