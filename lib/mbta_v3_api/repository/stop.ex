defmodule MBTAV3API.Repository.Stop do
  alias MBTAV3API.{JsonApi, Repository}
  @behaviour Repository.Behaviour.Stop

  @impl Repository.Behaviour.Stop
  def get_all(params, opts \\ []) do
    Application.get_env(:mobile_app_backend, Repository.Stop, Repository.Stop.Impl).get_all(
      params,
      opts
    )
  end
end

defmodule MBTAV3API.Repository.Stop.Impl do
  alias MBTAV3API.JsonApi

  def get_all(params, opts \\ []) do
    params = JsonApi.Params.flatten_params(params, :stop)

    case MBTAV3API.get_json("/stops", params, opts) do
      %JsonApi{data: data} -> {:ok, Enum.map(data, &MBTAV3API.Stop.parse/1)}
      {:error, error} -> {:error, error}
    end
  end
end
