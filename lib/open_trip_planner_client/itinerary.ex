defmodule OpenTripPlannerClient.Itinerary do
  @moduledoc """
  A trip at a particular time.

  An Itinerary is a single trip, with the legs being the different types of
  travel. Itineraries are separate even if they use the same modes but happen
  at different times of day.
  """

  alias OpenTripPlannerClient.Leg

  @enforce_keys [:start, :stop]
  defstruct [
    :start,
    :stop,
    legs: [],
    accessible?: false,
    tags: MapSet.new()
  ]

  @type t :: %__MODULE__{
          start: DateTime.t(),
          stop: DateTime.t(),
          legs: [Leg.t()],
          accessible?: boolean,
          tags: MapSet.t(atom())
        }

  @doc "Gets the time in seconds between the start and stop of the itinerary."
  @spec duration(t()) :: integer()
  def duration(%__MODULE__{start: start, stop: stop}) do
    DateTime.diff(stop, start, :second)
  end

  @doc "Total walking distance over all legs, in meters"
  @spec walking_distance(t) :: float
  def walking_distance(itinerary) do
    itinerary
    |> Enum.map(&Leg.walking_distance/1)
    |> Enum.sum()
  end

  @doc "Determines if two itineraries represent the same sequence of legs at the same time"
  @spec same_itinerary?(t, t) :: boolean
  def same_itinerary?(itinerary_1, itinerary_2) do
    itinerary_1.start == itinerary_2.start && itinerary_1.stop == itinerary_2.stop &&
      same_legs?(itinerary_2, itinerary_2)
  end

  @spec same_legs?(t, t) :: boolean
  defp same_legs?(%__MODULE__{legs: legs_1}, %__MODULE__{legs: legs_2}) do
    Enum.count(legs_1) == Enum.count(legs_2) &&
      legs_1 |> Enum.zip(legs_2) |> Enum.all?(fn {l1, l2} -> Leg.same_leg?(l1, l2) end)
  end

  defimpl Enumerable do
    alias OpenTripPlannerClient.Leg

    def count(%@for{legs: legs}) do
      Enumerable.count(legs)
    end

    def member?(%@for{legs: legs}, element) do
      Enumerable.member?(legs, element)
    end

    def reduce(%@for{legs: legs}, acc, fun) do
      Enumerable.reduce(legs, acc, fun)
    end

    def slice(%@for{legs: legs}) do
      Enumerable.slice(legs)
    end
  end
end
