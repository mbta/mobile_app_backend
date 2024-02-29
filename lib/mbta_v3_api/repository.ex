defmodule MBTAV3API.Repository do
  @moduledoc """
  Convenience functions for fetching data from the MBTA V3 API.
  """
  alias MBTAV3API.{JsonApi, Repository}

  @callback alerts(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, [MBTAV3API.Alert.t()]} | {:error, term()}

  @callback route_patterns(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, [MBTAV3API.RoutePattern.t()]} | {:error, term()}

  @callback routes(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, [MBTAV3API.Route.t()]} | {:error, term()}

  @callback stops(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, [MBTAV3API.Stop.t()]} | {:error, term()}

  def alerts(params, opts \\ []) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Repository, Repository.Impl).alerts(
      params,
      opts
    )
  end

  def route_patterns(params, opts \\ []) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Repository, Repository.Impl).route_patterns(
      params,
      opts
    )
  end

  def routes(params, opts \\ []) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Repository, Repository.Impl).routes(
      params,
      opts
    )
  end

  def stops(params, opts \\ []) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Repository, Repository.Impl).stops(
      params,
      opts
    )
  end
end

defmodule MBTAV3API.Repository.Impl do
  @behaviour MBTAV3API.Repository
  alias MBTAV3API.{Alert, JsonApi, Route, RoutePattern, Stop}

  @impl true
  def alerts(params, opts \\ []) do
    params = JsonApi.Params.flatten_params(params, Alert)

    case MBTAV3API.get_json("/alerts", params, opts) do
      %JsonApi{data: data} -> {:ok, Enum.map(data, &Alert.parse/1)}
      {:error, error} -> {:error, error}
    end
  end

  @impl true
  def route_patterns(params, opts \\ []) do
    params = JsonApi.Params.flatten_params(params, RoutePattern)

    case MBTAV3API.get_json("/route_patterns", params, opts) do
      %JsonApi{data: data} -> {:ok, Enum.map(data, &RoutePattern.parse/1)}
      {:error, error} -> {:error, error}
    end
  end

  @impl true
  def routes(params, opts \\ []) do
    params = JsonApi.Params.flatten_params(params, Route)

    case MBTAV3API.get_json("/routes", params, opts) do
      %JsonApi{data: data} -> {:ok, Enum.map(data, &Route.parse/1)}
      {:error, error} -> {:error, error}
    end
  end

  @impl true
  def stops(params, opts \\ []) do
    params = JsonApi.Params.flatten_params(params, Stop)

    case MBTAV3API.get_json("/stops", params, opts) do
      %JsonApi{data: data} -> {:ok, Enum.map(data, &Stop.parse/1)}
      {:error, error} -> {:error, error}
    end
  end
end
