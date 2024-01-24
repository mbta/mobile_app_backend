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
    with {:ok, edges} <- get_edges(data),
         {:ok, stops} <- parse_edges(edges) do
      {:ok, stops}
    else
      {:error, error} -> {:error, error}
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

  @spec get_edges(map()) :: {:ok, list(map())} | {:error, term()}
  defp get_edges(data) do
    case data do
      %{"data" => %{"nearest" => %{"edges" => edges}}} -> {:ok, edges}
      _ -> {:error, :bad_format}
    end
  end

  @spec parse_edges(list(map())) :: {:ok, list(MBTAV3API.Stop.t())} | {:error, term()}
  defp parse_edges(edges) do
    edges
    |> Enum.reduce({:ok, []}, fn
      edge, {:ok, reversed_stops} ->
        with {:ok, stop} <- get_stop(edge),
             {:ok, stop} <- parse_stop(stop) do
          {:ok, [stop | reversed_stops]}
        else
          :ignore -> {:ok, reversed_stops}
          {:error, error} -> {:error, error}
        end

      _edge, {:error, error} ->
        {:error, error}
    end)
    |> case do
      {:ok, reversed_stops} -> {:ok, Enum.reverse(reversed_stops)}
      {:error, error} -> {:error, error}
    end
  end

  @spec get_stop(map()) :: {:ok, map()} | {:error, term()}
  defp get_stop(edge) do
    case edge do
      %{"node" => %{"place" => stop}} -> {:ok, stop}
      _ -> {:error, :bad_format}
    end
  end

  @spec parse_stop(map()) :: {:ok, MBTAV3API.Stop.t()} | :ignore | {:error, term()}
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

      %{"gtfsId" => "2272_2274:" <> _} ->
        :ignore
    end
  end
end
