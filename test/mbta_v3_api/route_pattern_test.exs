defmodule MBTAV3API.RoutePatternTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  alias MBTAV3API.RoutePattern
  import MobileAppBackend.Factory

  test "parse/1" do
    assert RoutePattern.parse(%JsonApi.Item{
             id: "Green-C-832-1",
             attributes: %{
               "direction_id" => 1,
               "name" => "Cleveland Circle - Government Center",
               "sort_order" => 100_331_000,
               "typicality" => 1
             },
             relationships: %{
               "route" => %JsonApi.Reference{type: "route", id: "Green-C"},
               "representative_trip" => %JsonApi.Reference{type: "trip", id: "trip123"}
             }
           }) == %RoutePattern{
             id: "Green-C-832-1",
             direction_id: 1,
             name: "Cleveland Circle - Government Center",
             sort_order: 100_331_000,
             typicality: :typical,
             route_id: "Green-C",
             representative_trip_id: "trip123"
           }
  end

  describe "most_canonical_or_typical_per_route/1" do
    test "when no canonical routes, returns all patterns with the lowest non-nil typicality" do
      [nil, :typical, :deviation, :atypical, :diversion, :canonical_only]

      rps_0 = build_list(2, :route_pattern, %{typicality: nil})
      rps_1 = build_list(2, :route_pattern, %{typicality: :typical})
      rps_2 = build_list(2, :route_pattern, %{typicality: :deviation})
      rps_3 = build_list(2, :route_pattern, %{typicality: :atypical})
      rps_4 = build_list(2, :route_pattern, %{typicality: :diversion})
      rps_5 = build_list(2, :route_pattern, %{typicality: :canonical_only})

      assert ^rps_1 =
               RoutePattern.most_canonical_or_typical_per_route(
                 rps_5 ++ rps_0 ++ rps_4 ++ rps_1 ++ rps_3 ++ rps_2
               )
    end

    test "when canonical routes of different typicalities, returns canonical routes with the lowest non-nil typicality" do
      [nil, :typical, :deviation, :atypical, :diversion, :canonical_only]

      rps_0 = build_list(2, :route_pattern, %{typicality: nil})
      rps_1 = build_list(2, :route_pattern, %{typicality: :typical, canonical: true})
      rps_2 = build_list(2, :route_pattern, %{typicality: :deviation})
      rps_3 = build_list(2, :route_pattern, %{typicality: :atypical})
      rps_4 = build_list(2, :route_pattern, %{typicality: :diversion})
      rps_5 = build_list(2, :route_pattern, %{typicality: :canonical_only, canonical: true})

      assert ^rps_1 =
               RoutePattern.most_canonical_or_typical_per_route(
                 rps_5 ++ rps_0 ++ rps_4 ++ rps_1 ++ rps_3 ++ rps_2
               )
    end
  end

  describe "most_typical/1" do
    test "returns all patterns with the lowest non-nil typicality" do
      [nil, :typical, :deviation, :atypical, :diversion, :canonical_only]

      rps_0 = build_list(2, :route_pattern, %{typicality: nil})
      rps_1 = build_list(2, :route_pattern, %{typicality: :typical})
      rps_2 = build_list(2, :route_pattern, %{typicality: :deviation})
      rps_3 = build_list(2, :route_pattern, %{typicality: :atypical})
      rps_4 = build_list(2, :route_pattern, %{typicality: :diversion})
      rps_5 = build_list(2, :route_pattern, %{typicality: :canonical_only})

      assert ^rps_1 =
               RoutePattern.most_typical(rps_5 ++ rps_0 ++ rps_4 ++ rps_1 ++ rps_3 ++ rps_2)
    end
  end
end
