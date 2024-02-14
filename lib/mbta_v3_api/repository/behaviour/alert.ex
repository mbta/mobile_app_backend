defmodule MBTAV3API.Repository.Behaviour.Alert do
  @callback get_all(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, [MBTAV3API.Alert.t()]} | {:error, term()}
end
