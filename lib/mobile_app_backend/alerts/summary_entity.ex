defmodule MobileAppBackend.Alerts.SummaryEntity do
  @type t :: %__MODULE__{
          alert_id: String.t(),
          route_id: String.t() | nil,
          stop_id: String.t() | nil,
          trip_id: String.t() | nil,
          direction_id: (0 | 1) | nil,
          summary: String.t() | nil
        }

  @derive Jason.Encoder
  defstruct [:alert_id, :route_id, :stop_id, :trip_id, :direction_id, :summary]
end
