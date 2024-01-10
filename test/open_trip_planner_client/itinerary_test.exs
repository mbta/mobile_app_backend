defmodule OpenTripPlannerClient.ItineraryTest do
  use ExUnit.Case, async: true
  alias OpenTripPlannerClient.{Itinerary, Leg, PersonalDetail, TransitDetail}
  alias Test.Support.OpenTripPlannerClient, as: Support

  @from Support.random_stop()
  @to Support.random_stop()

  describe "duration/1" do
    test "calculates duration of itinerary" do
      itinerary = %Itinerary{start: DateTime.from_unix!(10), stop: DateTime.from_unix!(13)}

      assert Itinerary.duration(itinerary) == 3
    end
  end

  describe "walking_distance/1" do
    test "calculates walking distance of itinerary" do
      itinerary = %Itinerary{
        start: DateTime.from_unix!(10),
        stop: DateTime.from_unix!(13),
        legs: [
          %Leg{mode: %PersonalDetail{distance: 12.3}},
          %Leg{mode: %TransitDetail{}},
          %Leg{mode: %PersonalDetail{distance: 34.5}}
        ]
      }

      assert abs(Itinerary.walking_distance(itinerary) - 46.8) < 0.001
    end
  end

  describe "same_itinerary?" do
    test "Same itinerary is the same" do
      itinerary = Support.itinerary(@from, @to)
      assert Itinerary.same_itinerary?(itinerary, itinerary)
    end

    test "itineraries with different start times are not the same" do
      itinerary = Support.itinerary(@from, @to)
      later_itinerary = %{itinerary | start: Timex.shift(itinerary.start, minutes: 40)}
      refute Itinerary.same_itinerary?(itinerary, later_itinerary)
    end

    test "Itineraries with different accessibility flags are the same" do
      itinerary = Support.itinerary(@from, @to)
      accessible_itinerary = %{itinerary | accessible?: true}
      assert Itinerary.same_itinerary?(itinerary, accessible_itinerary)
    end
  end
end
