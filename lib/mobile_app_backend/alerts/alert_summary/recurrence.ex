defmodule MobileAppBackend.Alerts.AlertSummary.Recurrence do
  alias MobileAppBackend.Alerts.AlertSummary.Timeframe
  alias Util.PolymorphicJson

  @type end_day ::
          Timeframe.Tomorrow.t()
          | Timeframe.LaterDate.t()
          | Timeframe.ThisWeek.t()
          | Timeframe.UntilFurtherNotice.t()

  defmodule Daily do
    alias MobileAppBackend.Alerts.AlertSummary.Recurrence
    @type t :: %__MODULE__{ending: Recurrence.end_day()}
    @derive PolymorphicJson
    defstruct [:ending]
  end

  defmodule SomeDays do
    alias MobileAppBackend.Alerts.AlertSummary.Recurrence
    @type t :: %__MODULE__{ending: Recurrence.end_day()}
    @derive PolymorphicJson
    defstruct [:ending]
  end

  @type t :: Daily.t() | SomeDays.t()
end
