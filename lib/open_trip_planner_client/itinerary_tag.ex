defmodule OpenTripPlannerClient.ItineraryTag do
  @moduledoc """
  Logic for a tag which can be applied to itineraries which are the best by some criterion.
  """
  alias OpenTripPlannerClient.Itinerary

  @callback optimal :: :max | :min
  @callback score(Itinerary.t()) :: number() | nil
  @callback tag :: atom()

  @type t :: module()

  @doc """
  Applies the tag defined by the given module to the itinerary with the optimal score.

  If multiple itineraries are optimal, they will each get the tag.
  If all itineraries have a score of nil, nothing gets the tag.
  """
  @spec apply_tag(t(), [Itinerary.t()]) :: [Itinerary.t()]
  def apply_tag(tag_module, itineraries) do
    scores = itineraries |> Enum.map(&tag_module.score/1)
    {min_score, max_score} = Enum.min_max(scores |> Enum.reject(&is_nil/1), fn -> {nil, nil} end)

    best_score =
      case tag_module.optimal() do
        :max -> max_score
        :min -> min_score
      end

    Enum.zip(itineraries, scores)
    |> Enum.map(fn {itinerary, score} ->
      if not is_nil(score) and score == best_score do
        update_in(itinerary.tags, &MapSet.put(&1, tag_module.tag()))
      else
        itinerary
      end
    end)
  end
end
