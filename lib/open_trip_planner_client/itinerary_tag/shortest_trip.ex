defmodule OpenTripPlannerClient.ItineraryTag.ShortestTrip do
  @moduledoc false
  @behaviour OpenTripPlannerClient.ItineraryTag

  alias OpenTripPlannerClient.Itinerary

  @impl OpenTripPlannerClient.ItineraryTag
  def optimal, do: :min

  @impl OpenTripPlannerClient.ItineraryTag
  def score(%Itinerary{} = itinerary) do
    Itinerary.duration(itinerary)
  end

  @impl OpenTripPlannerClient.ItineraryTag
  def tag, do: :shortest_trip
end
