defmodule MobileAppBackend.Alerts.AlertSummary.Timeframe do
  alias Util.PolymorphicJson

  defmodule EndOfService do
    @type t :: %__MODULE__{}
    @derive PolymorphicJson
    defstruct []
  end

  defmodule Tomorrow do
    @type t :: %__MODULE__{}
    @derive PolymorphicJson
    defstruct []
  end

  defmodule LaterDate do
    @type t :: %__MODULE__{time: DateTime.t()}
    @derive PolymorphicJson
    defstruct [:time]
  end

  defmodule ThisWeek do
    @type t :: %__MODULE__{time: DateTime.t()}
    @derive PolymorphicJson
    defstruct [:time]
  end

  defmodule Time do
    @type t :: %__MODULE__{time: DateTime.t()}
    @derive PolymorphicJson
    defstruct [:time]
  end

  defmodule StartingTomorrow do
    @type t :: %__MODULE__{}
    @derive PolymorphicJson
    defstruct []
  end

  defmodule StartingLaterToday do
    @type t :: %__MODULE__{time: DateTime.t()}
    @derive PolymorphicJson
    defstruct [:time]
  end

  defmodule UntilFurtherNotice do
    @type t :: %__MODULE__{}
    @derive PolymorphicJson
    defstruct []
  end

  defmodule TimeRange do
    @type t :: %__MODULE__{start_time: start_time(), end_time: end_time()}
    @derive PolymorphicJson
    defstruct [:start_time, :end_time]

    defmodule StartOfService do
      @type t :: %__MODULE__{}
      @derive PolymorphicJson
      defstruct []
    end

    defmodule EndOfService do
      @type t :: %__MODULE__{}
      @derive PolymorphicJson
      defstruct []
    end

    defmodule Time do
      @type t :: %__MODULE__{time: DateTime.t()}
      @derive PolymorphicJson
      defstruct [:time]
    end

    @type start_time :: StartOfService.t() | Time.t()
    @type end_time :: EndOfService.t() | Time.t()
  end

  @type t ::
          EndOfService.t()
          | Tomorrow.t()
          | LaterDate.t()
          | ThisWeek.t()
          | Time.t()
          | StartingTomorrow.t()
          | StartingLaterToday.t()
          | UntilFurtherNotice.t()
end
