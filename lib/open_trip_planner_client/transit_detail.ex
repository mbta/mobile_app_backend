defmodule OpenTripPlannerClient.TransitDetail do
  @moduledoc """
  Additional information for legs taken on public transportation
  """

  defstruct route_id: "", trip_id: "", intermediate_stop_ids: []

  @type t :: %__MODULE__{
          route_id: String.t(),
          trip_id: String.t(),
          intermediate_stop_ids: [String.t()]
        }
end
