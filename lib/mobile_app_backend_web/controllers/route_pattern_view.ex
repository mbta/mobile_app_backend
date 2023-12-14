defmodule MobileAppBackendWeb.RoutePatternView do
  use JSONAPI.View, type: "routePattern"

  def fields do
    [
      :direction_id,
      :id,
      :name,
      :representative_trip_id,
      :representative_trip_polyline,
      :shape_id,
      :shape_priority,
      :headsign,
      :stop_ids,
      :route_id,
      :time_desc,
      :typicality,
      :service_id,
      :sort_order
    ]
  end
end
