defmodule OpenTripPlannerClient.ItineraryTag.LeastWalking do
  @moduledoc false
  @behaviour OpenTripPlannerClient.ItineraryTag

  alias OpenTripPlannerClient.Itinerary

  @impl OpenTripPlannerClient.ItineraryTag
  def optimal, do: :min

  @impl OpenTripPlannerClient.ItineraryTag
  def score(%Itinerary{} = itinerary) do
    Itinerary.walking_distance(itinerary)
  end

  @impl OpenTripPlannerClient.ItineraryTag
  def tag, do: :least_walking
end
