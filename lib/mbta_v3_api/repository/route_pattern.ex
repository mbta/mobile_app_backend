defmodule MBTAV3API.Repository.RoutePattern do
  alias MBTAV3API.{JsonApi, Repository}
  @behaviour Repository.Behaviour.RoutePattern

  @impl Repository.Behaviour.RoutePattern
  def get_all(params, opts \\ []) do
    Application.get_env(
      :mobile_app_backend,
      Repository.RoutePattern,
      Repository.RoutePattern.Impl
    ).get_all(params, opts)
  end
end

defmodule MBTAV3API.Repository.RoutePattern.Impl do
  alias MBTAV3API.JsonApi

  def get_all(params, opts \\ []) do
    params = JsonApi.Params.flatten_params(params, :route_pattern)

    case MBTAV3API.get_json("/route_patterns", params, opts) do
      %JsonApi{data: data} -> {:ok, Enum.map(data, &MBTAV3API.RoutePattern.parse/1)}
      {:error, error} -> {:error, error}
    end
  end
end
