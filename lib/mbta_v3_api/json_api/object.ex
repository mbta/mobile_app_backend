defmodule MBTAV3API.JsonApi.Object do
  @callback fields :: [atom()]
  @callback includes :: %{atom() => atom()}

  def module_for(type)
  def module_for(:route), do: MBTAV3API.Route
  def module_for(:route_pattern), do: MBTAV3API.RoutePattern
  def module_for(:stop), do: MBTAV3API.Stop
  def module_for(:trip), do: MBTAV3API.Trip
end
