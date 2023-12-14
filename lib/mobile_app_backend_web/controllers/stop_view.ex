defmodule MobileAppBackendWeb.StopView do
  use JSONAPI.View, type: "stop"

  def fields do
    [
      :id,
      :parent_id,
      :child_ids,
      :name,
      :note,
      :accessibility,
      :address,
      :municipality,
      :parking_lots,
      :fare_facilities,
      :bike_storage,
      :latitude,
      :longitude,
      :is_child?,
      :station?,
      :has_fare_machine?,
      :has_charlie_card_vendor?,
      :closed_stop_info,
      :type,
      :platform_name,
      :platform_code,
      :description,
      :zone
    ]
  end

  def fare_facilities(stop, _conn) do
    stop.fare_facilities |> Enum.to_list()
  end

  def bike_storage(stop, _conn) do
    stop.bike_storage |> Enum.to_list()
  end

  def relationships do
    [routes: MobileAppBackendWeb.RouteView]
  end
end
