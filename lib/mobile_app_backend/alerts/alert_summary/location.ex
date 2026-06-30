defmodule MobileAppBackend.Alerts.AlertSummary.Location do
  alias Util.PolymorphicJson

  defmodule DirectionToStop do
    @type t :: %__MODULE__{
            direction: Direction.t(),
            end_stop_name: String.t(),
            downstream: boolean() | nil
          }
    @derive PolymorphicJson
    defstruct [:direction, :end_stop_name, :downstream]
  end

  defmodule SingleStop do
    @type t :: %__MODULE__{stop_name: String.t(), downstream: boolean() | nil}
    @derive PolymorphicJson
    defstruct [:stop_name, :downstream]
  end

  defmodule StopToDirection do
    @type t :: %__MODULE__{
            start_stop_name: String.t(),
            direction: Direction.t(),
            downstream: boolean() | nil
          }
    @derive PolymorphicJson
    defstruct [:start_stop_name, :direction, :downstream]
  end

  defmodule SuccessiveStops do
    @type t :: %__MODULE__{
            start_stop_name: String.t(),
            end_stop_name: String.t(),
            downstream: boolean() | nil
          }
    @derive PolymorphicJson
    defstruct [:start_stop_name, :end_stop_name, :downstream]
  end

  defmodule WholeRoute do
    use Gettext, backend: MobileAppBackend.Gettext

    @type t :: %__MODULE__{route_label: String.t(), route_type: Route.type()}
    @derive PolymorphicJson
    defstruct [:route_label, :route_type]
  end

  defmodule AffectedStops do
    @type t :: %__MODULE__{stops: [String.t()] | nil}
    @derive PolymorphicJson
    defstruct [:stops]
  end

  @type t ::
          DirectionToStop.t()
          | SingleStop.t()
          | StopToDirection.t()
          | SuccessiveStops.t()
          | WholeRoute.t()
          | AffectedStops.t()
end
