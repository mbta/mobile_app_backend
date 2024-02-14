defmodule MBTAV3API.Repository.Behaviour.Stop do
  @callback get_all(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, [MBTAV3API.Stop.t()]} | {:error, term()}
end
