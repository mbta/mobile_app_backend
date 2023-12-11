defmodule MobileAppBackendWeb.RouteView do
  use JSONAPI.View, type: "route"

  def fields do
    [
      :id,
      :type,
      :name,
      :long_name,
      :color,
      :sort_order,
      :direction_names,
      :direction_destinations,
      :description,
      :fare_class,
      :custom_route?,
      :line_id
    ]
  end

  def direction_names(route, _conn) do
    route.direction_names |> Map.new(fn {k, v} -> {"#{k}", v} end)
  end

  def direction_destinations(route, _conn) do
    route.direction_destinations |> Map.new(fn {k, v} -> {"#{k}", v} end)
  end

  def relationships do
    [route_patterns: MobileAppBackendWeb.RoutePatternView]
  end
end
