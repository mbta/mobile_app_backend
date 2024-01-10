defmodule OpenTripPlannerClient.ItineraryTagTest do
  use ExUnit.Case, async: true
  alias OpenTripPlannerClient.{Itinerary, ItineraryTag}

  defmodule BadTag do
    @behaviour OpenTripPlannerClient.ItineraryTag

    def optimal, do: :max
    def score(_), do: nil
    def tag, do: :bad
  end

  test "correctly ignores tags that are always nil" do
    itineraries = [
      %Itinerary{start: ~U[2024-01-03 16:27:55Z], stop: ~U[2024-01-03 16:28:04Z]}
    ]

    tags = ItineraryTag.apply_tag(BadTag, itineraries) |> Enum.map(&Enum.sort(&1.tags))

    assert tags == [[]]
  end
end
