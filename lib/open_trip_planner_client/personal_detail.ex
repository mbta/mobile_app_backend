defmodule OpenTripPlannerClient.PersonalDetail do
  @moduledoc """
  Additional information for legs which are taken on personal transportation
  """
  defstruct distance: 0.0,
            steps: []

  @type t :: %__MODULE__{
          distance: float,
          steps: [__MODULE__.Step.t()]
        }
end

defmodule OpenTripPlannerClient.PersonalDetail.Step do
  @moduledoc """
  A turn-by-turn direction
  """
  defstruct distance: 0.0,
            relative_direction: :depart,
            absolute_direction: :north,
            street_name: ""

  @type t :: %__MODULE__{
          distance: float,
          relative_direction: relative_direction,
          absolute_direction: absolute_direction | nil
        }
  @type relative_direction ::
          :depart
          | :slightly_left
          | :left
          | :hard_left
          | :slightly_right
          | :right
          | :hard_right
          | :continue
          | :circle_clockwise
          | :circle_counterclockwise
          | :elevator
          | :uturn_left
          | :uturn_right
          | :enter_station
          | :exit_station
          | :follow_signs

  @type absolute_direction ::
          :north
          | :northeast
          | :east
          | :southeast
          | :south
          | :southwest
          | :west
          | :northwest
end
