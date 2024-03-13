defmodule MBTAV3API.Repository do
  @moduledoc """
  Convenience functions for fetching data from the MBTA V3 API.
  """
  alias MBTAV3API.{JsonApi, Repository}

  @callback alerts(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, JsonApi.Response.t(MBTAV3API.Alert.t())} | {:error, term()}

  @callback route_patterns(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, JsonApi.Response.t(MBTAV3API.RoutePattern.t())} | {:error, term()}

  @callback routes(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, JsonApi.Response.t(MBTAV3API.Route.t())} | {:error, term()}

  @callback schedules(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, JsonApi.Response.t(MBTAV3API.Schedule.t())} | {:error, term()}

  @callback stops(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, JsonApi.Response.t(MBTAV3API.Stop.t())} | {:error, term()}

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

  def schedules(params, opts \\ []) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Repository, Repository.Impl).schedules(
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
  alias MBTAV3API.JsonApi

  @impl true
  def alerts(params, opts \\ []), do: all(MBTAV3API.Alert, params, opts)

  @impl true
  def route_patterns(params, opts \\ []), do: all(MBTAV3API.RoutePattern, params, opts)

  @impl true
  def routes(params, opts \\ []), do: all(MBTAV3API.Route, params, opts)

  @impl true
  def schedules(params, opts \\ []), do: all(MBTAV3API.Schedule, params, opts)

  @impl true
  def stops(params, opts \\ []), do: all(MBTAV3API.Stop, params, opts)

  @spec all(module(), JsonApi.Params.t(), Keyword.t()) ::
          {:ok, JsonApi.Response.t(JsonApi.Object.t())} | {:error, term()}
  defp all(module, params, opts) do
    params = JsonApi.Params.flatten_params(params, module)
    url = "/#{JsonApi.Object.plural_type(module.jsonapi_type())}"

    case MBTAV3API.get_json(url, params, opts) do
      %JsonApi{} = doc -> {:ok, JsonApi.Response.parse(doc)}
      {:error, error} -> {:error, error}
    end
  end
end
