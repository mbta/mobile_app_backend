defmodule MobileAppBackend.StopPredictions.Store do
  @moduledoc """
  Interface for storing and updating the current state of predictions.
  """
  alias MBTAV3API.{JsonApi.Object, Route}

  # TODO: convert this to use ETS / make mor egeneral like dotcom.

  @callback by_route_id(Route.id()) :: Object.full_map()

  def by_route_id(route_id) do
    Application.get_env(
      :mobile_app_backend,
      __MODULE__,
      MobileAppBackend.StopPredictions.Store.Impl
    ).by_route_id(route_id)
  end
end

defmodule MobileAppBackend.StopPredictions.Store.Impl do
  @behaviour MobileAppBackend.StopPredictions.Store
  alias MBTAV3API.Stream

  def by_route_id(route_id) do
    GenServer.call(Stream.Registry.via_name("predictions:route:#{route_id}"), :get_data)
  end
end
