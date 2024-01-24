defmodule OpenTripPlannerClient.Nearby do
  @spec request(float(), float(), integer()) :: Req.Request.t()
  def request(latitude, longitude, radius) do
    Req.new(method: :post)
    |> AbsintheClient.attach(
      graphql: {graphql_query(), %{latitude: latitude, longitude: longitude, radius: radius}}
    )
  end

  @spec parse(map()) :: {:ok, [MBTAV3API.Stop.t()]} | {:error, term()}
  def parse(data) do
    case data do
      %{"data" => %{"nearest" => %{"edges" => edges}}} ->
        for edge <- edges, reduce: {:ok, []} do
          {:ok, stops} ->
            with %{"node" => %{"place" => stop}} <- edge,
                 {:ok, stop} <- parse_stop(stop) do
              {:ok, [stop | stops]}
            end
        end
        |> case do
          {:ok, stops} -> {:ok, Enum.reverse(stops)}
        end

      _ ->
        {:error, :bad_format}
    end
  end

  defp graphql_query do
    """
    query NearbyQuery($latitude: Float!, $longitude: Float!, $radius: Int!) {
      nearest(lat: $latitude, lon: $longitude, maxDistance: $radius, filterByPlaceTypes: [STOP]) {
        edges {
          node {
            place {
              ... on Stop {
                ...stopDetails
                parentStation {
                  ...stopDetails
                }
              }
            }
            distance
          }
        }
      }
    }

    fragment stopDetails on Stop {
      gtfsId
      lat
      lon
      name
    }
    """
  end

  @spec parse_stop(map()) :: {:ok, MBTAV3API.Stop.t()} | {:error, term()}
  defp parse_stop(place) do
    case place do
      %{"lat" => latitude, "lon" => longitude, "gtfsId" => "mbta-ma-us:" <> id, "name" => name} ->
        {:ok,
         %MBTAV3API.Stop{
           id: id,
           latitude: latitude,
           longitude: longitude,
           name: name,
           parent_station:
             with {:ok, parent_station} when not is_nil(parent_station) <-
                    Map.fetch(place, "parentStation"),
                  {:ok, parent_station} <- parse_stop(parent_station) do
               parent_station
             else
               _ -> nil
             end
         }}
    end
  end
end
