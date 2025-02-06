defmodule MobileAppBackend.Search.Algolia.StopResult do
  @moduledoc """
  Data returned by Algolia for stop search hits
  """
  @derive Jason.Encoder

  @type t :: %__MODULE__{
          type: :stop,
          id: String.t(),
          name: String.t(),
          rank: number(),
          zone: String.t() | nil,
          station?: boolean(),
          routes: [%{type: number(), icon: String.t()}]
        }

  defstruct [:type, :id, :name, :rank, :zone, :station?, :routes]

  @spec parse(map()) :: t()
  def parse(result_response) do
    %__MODULE__{
      type: :stop,
      id: result_response["stop"]["id"],
      name: result_response["stop"]["name"],
      rank: result_response["rank"],
      zone: result_response["stop"]["zone"],
      station?: result_response["stop"]["station?"],
      routes:
        Enum.map(
          result_response["routes"],
          &%{type: MBTAV3API.Route.parse_type!(&1["type"]), icon: &1["icon"]}
        )
    }
  end
end
