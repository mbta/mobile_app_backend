defmodule OpenTripPlannerClient.ItineraryTag.LeastWalkingTest do
  use ExUnit.Case, async: true
  alias OpenTripPlannerClient.{Itinerary, ItineraryTag, Leg, PersonalDetail, TransitDetail}

  test "works" do
    itineraries = [
      %Itinerary{
        start: ~U[2024-01-03 04:00:00Z],
        stop: ~U[2024-01-03 05:15:00Z],
        legs: [%Leg{mode: %TransitDetail{}}]
      },
      %Itinerary{
        start: ~U[2024-01-03 04:00:00Z],
        stop: ~U[2024-01-03 05:15:00Z],
        legs: [%Leg{mode: %PersonalDetail{distance: 10}}]
      },
      %Itinerary{
        start: ~U[2024-01-03 04:00:00Z],
        stop: ~U[2024-01-03 05:15:00Z],
        legs: [%Leg{mode: %PersonalDetail{distance: 8}}, %Leg{mode: %PersonalDetail{distance: 8}}]
      }
    ]

    tags =
      ItineraryTag.apply_tag(ItineraryTag.LeastWalking, itineraries)
      |> Enum.map(&(&1.tags |> Enum.sort()))

    assert tags == [[:least_walking], [], []]
  end
end
