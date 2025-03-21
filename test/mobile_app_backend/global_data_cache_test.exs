defmodule MobileAppBackend.GlobalDataCacheTest do
  use HttpStub.Case
  import MobileAppBackend.Factory
  alias MobileAppBackend.GlobalDataCache

  test "gets data" do
    cache_key = make_ref()

    start_link_supervised!({GlobalDataCache, key: cache_key})

    # makes HTTP requests from the current process, so Mox will behave correctly automatically
    retrieved_data = GlobalDataCache.get_data(cache_key)

    assert %{
             lines: lines,
             pattern_ids_by_stop: pattern_ids,
             routes: routes,
             route_patterns: route_patterns,
             stops: stops,
             trips: trips
           } = retrieved_data

    park_st_station = stops["place-pktrm"]

    assert %{
             id: "place-pktrm",
             name: "Park Street",
             location_type: :station,
             latitude: 42.356395,
             longitude: -71.062424,
             child_stop_ids: child_ids,
             connecting_stop_ids: connecting_ids
           } = park_st_station

    park_st_rl_platform = stops["70076"]

    assert %{
             id: "70076",
             name: "Park Street",
             location_type: :stop,
             parent_station_id: "place-pktrm"
           } = park_st_rl_platform

    assert child_ids |> Enum.member?("70076")
    assert connecting_ids |> Enum.member?("10000")

    park_st_rl_patterns = Map.get(pattern_ids, park_st_rl_platform.id)

    assert Enum.any?(park_st_rl_patterns, &(&1 == "Red-1-1"))
    assert Enum.any?(park_st_rl_patterns, &(&1 == "Red-3-1"))

    red_line_pattern = Map.get(route_patterns, "Red-1-1")

    assert %{
             direction_id: 1,
             id: "Red-1-1",
             name: "Ashmont - Alewife",
             representative_trip_id: red_line_trip_id,
             route_id: "Red",
             sort_order: 100_101_001
           } = red_line_pattern

    assert %{headsign: "Alewife", stop_ids: trip_stop_ids} = trips[red_line_trip_id]

    assert Enum.count(trip_stop_ids) == 17
    assert trip_stop_ids |> Enum.member?("70070")

    assert %{
             "Red" => %{
               color: "DA291C",
               direction_destinations: ["Ashmont/Braintree", "Alewife"],
               direction_names: ["South", "North"],
               id: "Red",
               line_id: "line-Red",
               long_name: "Red Line",
               type: :heavy_rail
             }
           } = routes

    assert %{
             "line-Red" => %{
               color: "DA291C",
               id: "line-Red",
               long_name: "Red Line",
               short_name: "",
               sort_order: 10_010,
               text_color: "FFFFFF"
             }
           } = lines
  end

  describe "init/1" do
    test "sends recalculation message" do
      cache_key = make_ref()

      :persistent_term.put(cache_key, %{
        lines: %{},
        pattern_ids_by_stop: %{},
        routes: %{},
        route_patterns: %{},
        stops: %{},
        trips: %{}
      })

      GlobalDataCache.init(key: cache_key, first_update_ms: 10)
      assert_receive :recalculate, 2_000
    end
  end

  describe "handle_info/1" do
    test "sends another recalculate message" do
      cache_key = make_ref()

      :persistent_term.put(cache_key, %{
        lines: %{},
        pattern_ids_by_stop: %{},
        routes: %{},
        route_patterns: %{},
        stops: %{},
        trips: %{}
      })

      GlobalDataCache.handle_info(:recalculate, %MobileAppBackend.GlobalDataCache.State{
        key: cache_key,
        update_ms: 10
      })

      assert_receive :recalculate
    end
  end

  describe "route_ids_for_stops/2" do
    test "returns route ids for the given stops only" do
      cache_key = make_ref()

      start_link_supervised!({GlobalDataCache, key: cache_key})

      :persistent_term.put(cache_key, %{
        lines: %{},
        pattern_ids_by_stop: %{
          "stop_1" => ["66_1", "39_1"],
          "stop_2" => ["66_2"],
          "stop_3" => ["15_1"]
        },
        routes: %{
          "66" => build(:route, id: "66"),
          "39" => build(:route, id: "39"),
          "15" => build(:route, id: "15")
        },
        route_patterns: %{
          "66_1" => build(:route_pattern, id: "66_1", route_id: "66"),
          "66_2" => build(:route_pattern, id: "66_2", route_id: "66"),
          "39_1" => build(:route_pattern, id: "39_1", route_id: "39"),
          "15_1" => build(:route_pattern, id: "15_1", route_id: "15")
        },
        stops: %{
          "stop_1" => build(:stop, id: "stop_1"),
          "stop_2" => build(:stop, id: "stop_2"),
          "stop_3" => build(:stop, id: "stop_3")
        },
        trips: %{}
      })

      assert ["39", "66"] =
               Enum.sort(GlobalDataCache.route_ids_for_stops(["stop_1", "stop_2"], cache_key))
    end
  end
end
