defmodule OpenTripPlannerClient.Leg do
  @moduledoc """
  A single-mode part of an Itinerary

  An Itinerary can take multiple modes of transportation (walk, bus,
  train, &c). Leg represents a single mode of travel during journey.
  """
  alias OpenTripPlannerClient.{NamedPosition, PersonalDetail, TransitDetail}

  defstruct start: DateTime.from_unix!(-1),
            stop: DateTime.from_unix!(0),
            mode: nil,
            from: nil,
            to: nil,
            name: nil,
            long_name: nil,
            type: nil,
            description: nil,
            url: nil,
            polyline: ""

  @type mode :: PersonalDetail.t() | TransitDetail.t()
  @type t :: %__MODULE__{
          start: DateTime.t(),
          stop: DateTime.t(),
          mode: mode,
          from: NamedPosition.t() | nil,
          to: NamedPosition.t(),
          name: String.t(),
          long_name: String.t(),
          type: String.t(),
          description: String.t(),
          url: String.t(),
          polyline: String.t()
        }

  @spec walking_distance(t) :: float
  def walking_distance(%__MODULE__{mode: %PersonalDetail{distance: nil}}), do: 0.0
  def walking_distance(%__MODULE__{mode: %PersonalDetail{distance: distance}}), do: distance
  def walking_distance(%__MODULE__{mode: %TransitDetail{}}), do: 0.0

  @doc "Determines if two legs have the same to and from fields"
  @spec same_leg?(t, t) :: boolean
  def same_leg?(%__MODULE__{from: from, to: to}, %__MODULE__{from: from, to: to}), do: true
  def same_leg?(_leg_1, _leg_2), do: false
end
