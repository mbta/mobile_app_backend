defmodule MBTAV3API.Repository.Behaviour.RoutePattern do
  @callback get_all(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, [MBTAV3API.RoutePattern.t()]} | {:error, term()}
end
