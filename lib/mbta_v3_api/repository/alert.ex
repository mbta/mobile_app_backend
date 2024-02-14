defmodule MBTAV3API.Repository.Alert do
  alias MBTAV3API.{JsonApi, Repository}
  @behaviour Repository.Behaviour.Alert

  @impl Repository.Behaviour.Alert
  def get_all(params, opts \\ []) do
    Application.get_env(:mobile_app_backend, Repository.Alert, Repository.Alert.Impl).get_all(
      params,
      opts
    )
  end
end

defmodule MBTAV3API.Repository.Alert.Impl do
  alias MBTAV3API.JsonApi

  def get_all(params, opts \\ []) do
    params = JsonApi.Params.flatten_params(params, :alert)

    case MBTAV3API.get_json("/alerts", params, opts) do
      %JsonApi{data: data} -> {:ok, Enum.map(data, &MBTAV3API.Alert.parse/1)}
      {:error, error} -> {:error, error}
    end
  end
end
