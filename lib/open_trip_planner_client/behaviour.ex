defmodule OpenTripPlannerClient.Behaviour do
  @moduledoc """
  A behaviour that specifies the API for the `OpenTripPlannerClient`.

  May be useful for testing with libraries like [Mox](https://hex.pm/packages/mox).
  """

  alias OpenTripPlannerClient.{Itinerary, ItineraryTag, NamedPosition}

  @type plan_opt ::
          {:arrive_by, DateTime.t()}
          | {:depart_at, DateTime.t()}
          | {:wheelchair_accessible?, boolean}
          | {:optimize_for, :less_walking | :fewest_transfers}
          | {:tags, [ItineraryTag.t()]}

  @type error ::
          :outside_bounds
          | :timeout
          | :no_transit_times
          | :too_close
          | :location_not_accessible
          | :path_not_found
          | :unknown

  @callback plan(from :: NamedPosition.t(), to :: NamedPosition.t(), opts :: [plan_opt()]) ::
              {:ok, Itinerary.t()} | {:error, error()}
end
