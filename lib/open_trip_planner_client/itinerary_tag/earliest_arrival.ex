defmodule OpenTripPlannerClient.ItineraryTag.EarliestArrival do
  @moduledoc false
  @behaviour OpenTripPlannerClient.ItineraryTag

  alias OpenTripPlannerClient.Itinerary

  @impl OpenTripPlannerClient.ItineraryTag
  def optimal, do: :min

  @impl OpenTripPlannerClient.ItineraryTag
  def score(%Itinerary{} = itinerary) do
    itinerary.stop |> DateTime.to_unix()
  end

  @impl OpenTripPlannerClient.ItineraryTag
  def tag, do: :earliest_arrival
end
