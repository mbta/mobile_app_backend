defmodule MobileAppBackend.Search.Algolia.RouteResult do
  @moduledoc """
  Data returned by Algolia for route search hits
  """
  @derive Jason.Encoder

  @type t :: %__MODULE__{
          type: :route,
          id: String.t(),
          name: String.t(),
          long_name: String.t(),
          route_type: number(),
          rank: number()
        }

  defstruct [:type, :id, :name, :long_name, :route_type, :rank]

  @spec parse(map()) :: t()
  def parse(result_response) do
    %__MODULE__{
      type: :route,
      id: result_response["route"]["id"],
      name: result_response["route"]["name"],
      long_name: result_response["route"]["long_name"],
      route_type: result_response["route"]["type"],
      rank: result_response["rank"]
    }
  end
end
