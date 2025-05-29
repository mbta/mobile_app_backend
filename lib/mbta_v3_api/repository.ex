defmodule MBTAV3API.Repository do
  @moduledoc """
  Convenience functions for fetching data from the MBTA V3 API.
  """
  alias MBTAV3API.{JsonApi, Repository}

  @callback alerts(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, JsonApi.Response.t(MBTAV3API.Alert.t())} | {:error, term()}

  @callback facilities(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, JsonApi.Response.t(MBTAV3API.Facility.t())} | {:error, term()}

  @callback route_patterns(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, JsonApi.Response.t(MBTAV3API.RoutePattern.t())} | {:error, term()}

  @callback routes(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, JsonApi.Response.t(MBTAV3API.Route.t())} | {:error, term()}

  @callback schedules(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, JsonApi.Response.t(MBTAV3API.Schedule.t())} | {:error, term()}

  @callback stops(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, JsonApi.Response.t(MBTAV3API.Stop.t())} | {:error, term()}

  @callback trips(JsonApi.Params.t(), Keyword.t()) ::
              {:ok, JsonApi.Response.t(MBTAV3API.Trip.t())} | {:error, term()}

  def alerts(params, opts \\ []) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Repository, Repository.Impl).alerts(
      params,
      opts
    )
  end

  def facilities(params, opts \\ []) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Repository, Repository.Impl).facilities(
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

  def trips(params, opts \\ []) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Repository, Repository.Impl).trips(
      params,
      opts
    )
  end
end

defmodule MBTAV3API.Repository.Impl do
  @behaviour MBTAV3API.Repository

  use Nebulex.Caching.Decorators

  alias MBTAV3API.{JsonApi, RepositoryCache}

  @ttl :timer.hours(1)

  @impl true
  def alerts(params, opts \\ []), do: all(MBTAV3API.Alert, params, opts)

  @impl true
  @decorate cacheable(cache: RepositoryCache, on_error: :nothing, opts: [ttl: @ttl])
  def facilities(params, opts \\ []), do: all(MBTAV3API.Facility, params, opts)

  @impl true
  @decorate cacheable(cache: RepositoryCache, on_error: :nothing, opts: [ttl: @ttl])
  def route_patterns(params, opts \\ []), do: all(MBTAV3API.RoutePattern, params, opts)

  @impl true
  @decorate cacheable(cache: RepositoryCache, on_error: :nothing, opts: [ttl: @ttl])
  def routes(params, opts \\ []), do: all(MBTAV3API.Route, params, opts)

  @impl true
  @decorate cacheable(cache: RepositoryCache, on_error: :nothing, opts: [ttl: @ttl])
  def schedules(params, opts \\ []), do: all(MBTAV3API.Schedule, params, opts)

  @impl true
  @decorate cacheable(cache: RepositoryCache, on_error: :nothing, opts: [ttl: @ttl])
  def stops(params, opts \\ []), do: all(MBTAV3API.Stop, params, opts)

  @impl true
  @decorate cacheable(cache: RepositoryCache, on_error: :nothing, opts: [ttl: @ttl])
  def trips(params, opts \\ []), do: all(MBTAV3API.Trip, params, opts)

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
