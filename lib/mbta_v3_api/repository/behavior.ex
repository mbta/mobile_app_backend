defmodule MBTAV3API.Repository.Behaviour do
  alias MBTAV3API.JsonApi

  @callback all_alerts(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, [MBTAV3API.Alert.t()]} | {:error, term()}

  @callback all_route_patterns(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, [MBTAV3API.RoutePattern.t()]} | {:error, term()}

  @callback all_stops(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, [MBTAV3API.Stop.t()]} | {:error, term()}
end
