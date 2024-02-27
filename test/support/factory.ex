defmodule MobileAppBackend.Factory do
  import Test.Support.Sigils

  use ExMachina

  def stop_factory do
    %MBTAV3API.Stop{
      id: "22549",
      name: "Harvard Sq @ Garden St - Dawes Island",
      latitude: 42.375302,
      longitude: -71.119237,
      location_type: :stop
    }
  end

  def route_pattern_factory do
    %MBTAV3API.RoutePattern{
      id: "66-6-0",
      name: "Nubian Station - Harvard Square",
      direction_id: 0,
      sort_order: 506_600_000
    }
  end

  def route_factory do
    %MBTAV3API.Route{
      id: "66",
      long_name: "Harvard Square - Nubian Station",
      short_name: "66",
      type: :bus,
      direction_names: ["Outbound", "Inbound"],
      direction_destinations: ["Harvard Square", "Nubian Station"],
      text_color: "000000"
    }
  end

  def trip_factory do
    %MBTAV3API.Trip{
      id: "60168428",
      headsign: "Harvard via Allston"
    }
  end

  def alert_factory do
    %MBTAV3API.Alert{
      id: "553702",
      active_period: [
        %MBTAV3API.Alert.ActivePeriod{
          start: ~B[2024-02-14T05:22:00],
          end: ~B[2024-02-14T12:34:41]
        }
      ],
      effect: :delay,
      informed_entity: [
        %MBTAV3API.Alert.InformedEntity{
          activities: [:board, :exit, :ride],
          route: "66",
          route_type: :bus
        }
      ],
      lifecycle: :new
    }
  end
end
