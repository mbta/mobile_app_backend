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
    :updated_at
  ]

  @spec from_alert(Alert.t(), [SummaryEntity.t()]) :: t()
  def from_alert(alert, summaries),
    do: struct(%__MODULE__{summaries: summaries}, Map.from_struct(alert))
end
