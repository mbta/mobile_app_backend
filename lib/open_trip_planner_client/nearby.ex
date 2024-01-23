defmodule OpenTripPlannerClient.Nearby do
  @spec request(float(), float(), integer()) :: Req.Request.t()
  def request(latitude, longitude, radius) do
    Req.new(method: :post)
    |> AbsintheClient.attach(
      graphql: {graphql_query(), %{latitude: latitude, longitude: longitude, radius: radius}}
    )
  end

  @spec parse(map()) ::
          {:ok, {[MBTAV3API.Stop.t()], [MBTAV3API.RoutePattern.t()]}}
          | {:error, term()}
  def parse(data) do
    case data do
      %{"data" => %{"nearest" => %{"edges" => edges}}} ->
        for edge <- edges, reduce: {:ok, {[], %{}}} do
          {:ok, {stops, route_patterns}} ->
            with %{"node" => %{"place" => stop}} <- edge,
                 {:ok, {stop, new_route_patterns}} <- parse_stop(stop) do
              {:ok,
               {[stop | stops],
                Map.merge(route_patterns, new_route_patterns, fn _,
                                                                 %MBTAV3API.RoutePattern{
                                                                   representative_trip:
                                                                     %MBTAV3API.Trip{
                                                                       stops: stops1
                                                                     }
                                                                 } = pattern,
                                                                 %MBTAV3API.RoutePattern{
                                                                   representative_trip:
                                                                     %MBTAV3API.Trip{
                                                                       stops: stops2
                                                                     }
                                                                 } ->
                  put_in(pattern.representative_trip.stops, stops1 ++ stops2)
                end)}}
            end
        end
        |> case do
          {:ok, {stops, patterns}} -> {:ok, {Enum.reverse(stops), Map.values(patterns)}}
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
                patterns {
                  route {
                    gtfsId
                    shortName
                    longName
                    mode
                    color
                    textColor
                  }
                  directionId
                  name
                  code
                  headsign
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

  @spec parse_stop(map()) ::
          {:ok, {MBTAV3API.Stop.t(), %{String.t() => MBTAV3API.RoutePattern.t()}}}
          | {:error, term()}
  defp parse_stop(place) do
    case place do
      %{"lat" => latitude, "lon" => longitude, "gtfsId" => "mbta-ma-us:" <> id, "name" => name} ->
        {:ok,
         {
           %MBTAV3API.Stop{
             id: id,
             latitude: latitude,
             longitude: longitude,
             name: name,
             parent_station:
               with {:ok, parent_station} when not is_nil(parent_station) <-
                      Map.fetch(place, "parentStation"),
                    {:ok, {parent_station, _}} <- parse_stop(parent_station) do
                 parent_station
               else
                 _ -> nil
               end
           },
           Map.get(place, "patterns", [])
           |> Enum.map(&parse_pattern(&1, id))
           |> Map.new(&{&1.id, &1})
         }}
    end
  end

  defp parse_pattern(pattern, stop_id) do
    %MBTAV3API.RoutePattern{
      id: pattern["code"] |> String.replace_prefix("mbta-ma-us:", ""),
      direction_id: pattern["directionId"],
      name: pattern["name"],
      sort_order: nil,
      representative_trip: %MBTAV3API.Trip{
        stops: [%MBTAV3API.JsonApi.Reference{type: "stop", id: stop_id}]
      },
      route: %MBTAV3API.Route{
        id: pattern["route"]["gtfsId"] |> String.replace_prefix("mbta-ma-us:", ""),
        color: pattern["route"]["color"],
        direction_destinations: nil,
        direction_names: nil,
        long_name: pattern["route"]["longName"],
        short_name: pattern["route"]["shortName"],
        sort_order: nil,
        text_color: pattern["route"]["textColor"]
      }
    }
  end
end
