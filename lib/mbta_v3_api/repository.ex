defmodule MBTAV3API.Repository do
  alias MBTAV3API.{JsonApi, Repository}
  @behaviour Repository.Behaviour

  @impl Repository.Behaviour
  def all_alerts(params, opts \\ []) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Repository, Repository.Impl).all_alerts(
      params,
      opts
    )
  end

  @impl Repository.Behaviour
  def all_route_patterns(params, opts \\ []) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Repository, Repository.Impl).all_route_patterns(
      params,
      opts
    )
  end

  @impl Repository.Behaviour
  def all_stops(params, opts \\ []) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Repository, Repository.Impl).all_stops(
      params,
      opts
    )
  end
end

defmodule MBTAV3API.Repository.Impl do
  alias MBTAV3API.JsonApi

  def all_alerts(params, opts \\ []) do
    params = JsonApi.Params.flatten_params(params, :alert)

    case MBTAV3API.get_json("/alerts", params, opts) do
      %JsonApi{data: data} -> {:ok, Enum.map(data, &MBTAV3API.Alert.parse/1)}
      {:error, error} -> {:error, error}
    end
  end

  def all_route_patterns(params, opts \\ []) do
    params = JsonApi.Params.flatten_params(params, :route_pattern)

    case MBTAV3API.get_json("/route_patterns", params, opts) do
      %JsonApi{data: data} -> {:ok, Enum.map(data, &MBTAV3API.RoutePattern.parse/1)}
      {:error, error} -> {:error, error}
    end
  end

  def all_stops(params, opts \\ []) do
    params = JsonApi.Params.flatten_params(params, :stop)

    case MBTAV3API.get_json("/stops", params, opts) do
      %JsonApi{data: data} -> {:ok, Enum.map(data, &MBTAV3API.Stop.parse/1)}
      {:error, error} -> {:error, error}
    end
  end
end
