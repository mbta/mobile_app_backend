defmodule Routes.RouteTest do
  use ExUnit.Case, async: true
  alias Routes.{Repo, Route}

  describe "type_atom/1" do
    test "returns an atom for the route type" do
      for {key, expected_result} <- [
            {0, :subway},
            {1, :subway},
            {2, :commuter_rail},
            {3, :bus},
            {4, :ferry},
            {"909", :logan_express},
            {"983", :massport_shuttle},
            {"Massport-1", :massport_shuttle},
            {"the_ride", :the_ride}
          ] do
        assert Route.type_atom(key) == expected_result
      end
    end

    test "handles hyphen in commuter-rail" do
      assert Route.type_atom("commuter-rail") == :commuter_rail
      assert Route.type_atom("commuter_rail") == :commuter_rail
    end

    test "extracts the type integer from the route struct and returns the corresponding atom" do
      assert Route.type_atom(%Route{type: 3}) == :bus
    end
  end

  describe "icon_atom/1" do
    test "for subways, returns the name of the line as an atom" do
      for {expected, id} <- [
            red_line: "Red",
            mattapan_line: "Mattapan",
            orange_line: "Orange",
            blue_line: "Blue",
            green_line: "Green",
            green_line_b: "Green-B"
          ] do
        route = %Route{id: id}
        actual = Route.icon_atom(route)
        assert actual == expected
      end
    end

    test "for other routes, returns an atom based on the type" do
      for {expected, type} <- [commuter_rail: 2, bus: 3, ferry: 4] do
        route = %Route{type: type}
        actual = Route.icon_atom(route)
        assert actual == expected
      end
    end
  end

  describe "path_atom/1" do
    test "hyphenates the :commuter_rail atom for path usage" do
      assert Route.path_atom(%Route{type: 2}) == :"commuter-rail"
      assert Route.path_atom(%Route{type: 3}) == :bus
    end
  end

  describe "types_for_mode/1" do
    test "returns correct mode list for each mode" do
      assert Route.types_for_mode(:subway) == [0, 1]
      assert Route.types_for_mode(:commuter_rail) == [2]
      assert Route.types_for_mode(:bus) == [3]
      assert Route.types_for_mode(:ferry) == [4]

      for light_rail <- [:green_line, :mattapan_line],
          do: assert(Route.types_for_mode(light_rail) == [0])

      for heavy_rail <- [:red_line, :orange_line, :blue_line],
          do: assert(Route.types_for_mode(heavy_rail) == [1])
    end
  end

  describe "type_name/1" do
    test "titleizes the name" do
      for {atom, str} <- [
            subway: "Subway",
            bus: "Bus",
            ferry: "Ferry",
            commuter_rail: "Commuter Rail",
            the_ride: "The RIDE"
          ] do
        assert Route.type_name(atom) == str
      end
    end
  end

  describe "type_summary" do
    test "lists route names for bus routes" do
      routes = [%Route{id: "1", name: "1", type: 3}, %Route{id: "747", name: "SL1", type: 3}]
      assert Route.type_summary(:bus, routes) == "Bus: 1, SL1"
    end

    test "returns type name for all other route types" do
      assert Route.type_summary(:green_line, [
               %Route{id: "Green-C", name: "Green Line C", type: 0},
               %Route{id: "Green-C", name: "Green Line C", type: 0}
             ]) == "Green Line"

      assert Route.type_summary(:mattapan_trolley, [
               %Route{id: "Mattapan", name: "Mattapan", type: 0}
             ]) ==
               "Mattapan Trolley"

      assert Route.type_summary(:red_line, [%Route{id: "Red", name: "Red Line", type: 1}]) ==
               "Red Line"

      assert Route.type_summary(:commuter_rail, [
               %Route{id: "CR-Fitchburg", name: "Fitchburg", type: 2}
             ]) ==
               "Commuter Rail"

      assert Route.type_summary(:ferry, [%Route{id: "Boat-F1", name: "Hull Ferry", type: 4}]) ==
               "Ferry"
    end
  end

  describe "direction_name/2" do
    test "returns the name of the direction" do
      assert Route.direction_name(%Route{}, 0) == "Outbound"
      assert Route.direction_name(%Route{}, 1) == "Inbound"

      assert Route.direction_name(%Route{direction_names: %{0 => "Northbound"}}, 0) ==
               "Northbound"

      assert Route.direction_name(%Route{direction_names: %{0 => "Southbound"}}, 0) ==
               "Southbound"

      assert Route.direction_name(%Route{direction_names: %{0 => "Eastbound"}}, 0) == "Eastbound"
      assert Route.direction_name(%Route{direction_names: %{0 => "Westbound"}}, 0) == "Westbound"
      assert Route.direction_name(%Route{direction_names: %{0 => ""}}, 0) == ""
    end
  end

  describe "direction_destination/2" do
    test "returns the destination of the direction" do
      route = %Route{
        direction_destinations: %{
          0 => "Start",
          1 => "End"
        }
      }

      assert Route.direction_destination(route, 0) == "Start"
      assert Route.direction_destination(route, 1) == "End"
    end
  end

  describe "vehicle_name/1" do
    test "returns the appropriate type of vehicle" do
      for {type, name} <- [
            {0, "Train"},
            {1, "Train"},
            {2, "Train"},
            {3, "Bus"},
            {4, "Boat"}
          ] do
        assert Route.vehicle_name(%Route{type: type}) == name
      end
    end
  end

  describe "key_route?" do
    test "true if rapid transit or key bus route" do
      assert Route.key_route?(%Route{description: :key_bus_route})
      assert Route.key_route?(%Route{description: :rapid_transit})
    end
  end

  describe "silver_line?/1" do
    test "returns true if a route id is in @silver_line" do
      assert Route.silver_line?(%Route{id: "741"})
      refute Route.silver_line?(%Route{id: "747"})
    end
  end

  describe "to_naive/1" do
    test "turns a green line branch into a generic green line route" do
      green_line_route = Repo.green_line()

      for branch <- ["B", "C", "D", "E"] do
        assert Route.to_naive(%Route{
                 id: "Green-" <> branch,
                 name: "Green Line " <> branch,
                 type: 0
               }) == green_line_route
      end
    end

    test "does nothing for other routes" do
      route = %Route{id: "Red", type: 1}
      assert Route.to_naive(route) == route
    end
  end

  describe "to_json_safe/1" do
    test "converts a Route to a Json string with safe object keys" do
      route = %Route{
        custom_route?: false,
        description: :rapid_transit,
        direction_destinations: %{0 => "Ashmont/Braintree", 1 => "Alewife"},
        direction_names: %{0 => "South", 1 => "North"},
        id: "Red",
        long_name: "Red Line",
        name: "Red Line",
        type: 1,
        color: "DA291C",
        sort_order: 5
      }

      expected = %{
        custom_route?: false,
        description: :rapid_transit,
        direction_destinations: %{"0" => "Ashmont/Braintree", "1" => "Alewife"},
        direction_names: %{"0" => "South", "1" => "North"},
        id: "Red",
        long_name: "Red Line",
        name: "Red Line",
        type: 1,
        color: "DA291C",
        sort_order: 5,
        fare_class: :unknown_fare,
        line_id: ""
      }

      assert Route.to_json_safe(route) == expected
    end
  end

  describe "hidden?/1" do
    test "Returns true for hidden routes" do
      hidden_routes = [
        "2427",
        "3233",
        "3738",
        "4050",
        "725",
        "8993",
        "116117",
        "214216",
        "441442",
        "9701",
        "9702",
        "9703",
        "Logan-Airport",
        "CapeFlyer"
      ]

      for route_id <- hidden_routes do
        assert Route.hidden?(%{id: route_id})
      end
    end

    test "Returns false for non hidden routes" do
      visible_routes = ["SL1", "66", "1", "742"]

      for route_id <- visible_routes do
        refute Route.hidden?(%{id: route_id})
      end
    end
  end

  describe "rail?/1" do
    test "returns true if a route is on rails" do
      assert Route.rail?(%Route{type: 0})
      assert Route.rail?(%Route{type: 1})
      assert Route.rail?(%Route{type: 2})
      refute Route.rail?(%Route{type: 3})
      refute Route.rail?(%Route{type: 4})
    end
  end
end
