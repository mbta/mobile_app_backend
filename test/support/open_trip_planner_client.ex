defmodule Test.Support.OpenTripPlannerClient do
  alias OpenTripPlannerClient.{Itinerary, Leg, NamedPosition, PersonalDetail, TransitDetail}

  @max_distance 1000
  @max_duration 30 * 60

  @stops [
    %NamedPosition{
      name: "South Station",
      stop_id: "place-sstat",
      latitude: 42.352271,
      longitude: -71.055242
    },
    %NamedPosition{
      name: "North Station",
      stop_id: "place-north",
      latitude: 42.365577,
      longitude: -71.06129
    },
    %NamedPosition{
      name: "Back Bay",
      stop_id: "place-bbsta",
      latitude: 42.34735,
      longitude: -71.075727
    },
    %NamedPosition{
      name: "Park Street",
      stop_id: "place-pktrm",
      latitude: 42.356395,
      longitude: -71.062424
    },
    %NamedPosition{
      name: "Ruggles",
      stop_id: "place-rugg",
      latitude: 42.336377,
      longitude: -71.088961
    },
    %NamedPosition{
      name: "Government Center",
      stop_id: "place-gover",
      latitude: 42.359705,
      longitude: -71.059215
    }
  ]

  @routes [
    %{route_id: "1", trip_id: "60168424", stop_id: "64"},
    %{route_id: "350", trip_id: "60144732", stop_id: "141"},
    %{route_id: "Blue", trip_id: "59736514", stop_id: "70038"},
    %{route_id: "Red", trip_id: "60392545", stop_id: "70105"}
  ]

  def itinerary(from, to, opts \\ []) do
    start = DateTime.utc_now()
    duration = :rand.uniform(@max_duration)
    stop = Timex.shift(start, seconds: duration)
    midpoint_stop1 = random_stop([from.stop_id, to.stop_id])
    midpoint_time1 = Timex.shift(start, seconds: Integer.floor_div(duration, 3))
    midpoint_stop2 = random_stop([from.stop_id, to.stop_id, midpoint_stop1.stop_id])
    midpoint_time2 = Timex.shift(start, seconds: Integer.floor_div(duration, 3) * 2)

    %Itinerary{
      start: start,
      stop: stop,
      legs: [
        personal_leg(from, midpoint_stop1, start, midpoint_time1),
        transit_leg(midpoint_stop1, midpoint_stop2, midpoint_time1, midpoint_time2),
        personal_leg(midpoint_stop2, to, midpoint_time2, stop)
      ],
      accessible?: Keyword.get(opts, :wheelchair_accessible?, false)
    }
  end

  def random_stop(without_stop_ids \\ []) do
    Enum.reject(@stops, &Enum.member?(without_stop_ids, &1.stop_id)) |> Enum.random()
  end

  def personal_leg(from, to, start, stop) do
    distance = :rand.uniform() * @max_distance

    %Leg{
      start: start,
      stop: stop,
      from: from,
      to: to,
      mode: %PersonalDetail{distance: distance, steps: [random_step(), random_step()]}
    }
  end

  def random_step do
    distance = :rand.uniform() * @max_distance
    absolute_direction = Enum.random(~w(north east south west)a)
    relative_direction = Enum.random(~w(left right depart continue)a)
    street_name = "Random Street"

    %PersonalDetail.Step{
      distance: distance,
      relative_direction: relative_direction,
      absolute_direction: absolute_direction,
      street_name: street_name
    }
  end

  def transit_leg(from, to, start, stop) do
    %{route_id: route_id, trip_id: trip_id, stop_id: stop_id} = Enum.random(@routes)

    %Leg{
      start: start,
      stop: stop,
      from: from,
      to: to,
      mode: %TransitDetail{
        route_id: route_id,
        trip_id: trip_id,
        intermediate_stop_ids:
          Enum.random([
            [stop_id],
            []
          ])
      }
    }
  end
end
