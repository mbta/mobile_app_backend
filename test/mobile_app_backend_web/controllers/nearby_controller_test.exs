defmodule MobileAppBackendWeb.NearbyControllerTest do
  use HttpStub.Case
  use MobileAppBackendWeb.ConnCase
  import Mox
  import Test.Support.Helpers
  import MobileAppBackend.Factory

  describe "GET /api/nearby unit tests" do
    setup do
      verify_on_exit!()
      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    end

    test "returns stop and route patterns with expected fields", %{conn: conn} do
      stop1 = build(:stop, %{id: "stop1", name: "Stop 1"})
      stop2 = build(:stop, %{id: "stop2", name: "Stop 2"})

      RepositoryMock
      |> expect(:stops, 2, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:route_type) do
          [:light_rail, :heavy_rail, :bus, :ferry] ->
            ok_response([stop1, stop2])

          _ ->
            ok_response([])
        end
      end)

      conn =
        get(conn, "/api/nearby", %{
          latitude: 42.281219333648,
          longitude: -71.17594685509955
        })

      assert %{"stop_ids" => ["stop1", "stop2"]} = json_response(conn, 200)
    end

    test "includes both physical and logical platforms at stops with both", %{conn: conn} do
      parent_station =
        build(:stop, id: "place-forhl", child_stop_ids: ["70001", "Forest Hills-01"])

      logical_platform = build(:stop, id: "70001", parent_station_id: "place-forhl")
      physical_platform = build(:stop, id: "Forest Hills-01", parent_station_id: "place-forhl")

      RepositoryMock
      |> expect(:stops, 2, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:route_type) do
          [:light_rail, :heavy_rail, :bus, :ferry] ->
            ok_response([logical_platform, physical_platform], [parent_station])

          _ ->
            ok_response([])
        end
      end)

      conn =
        get(conn, "/api/nearby", %{
          latitude: 1.2,
          longitude: -3.4
        })

      %{"stop_ids" => stop_ids} = json_response(conn, 200)

      assert ["70001", "Forest Hills-01"] = stop_ids
    end

    test "includes out of range sibling stops for any stops in range", %{conn: conn} do
      parent_stop_id = "parent"
      in_range_stop_id = "in_range_sibling"
      out_of_range_stop_id = "out_of_range_sibling"

      parent =
        build(:stop, %{
          id: parent_stop_id,
          name: "Stop 1",
          location_type: :station,
          child_stop_ids: [in_range_stop_id, out_of_range_stop_id]
        })

      in_range_sibling =
        build(:stop, %{id: in_range_stop_id, name: "Stop 1", parent_station_id: parent_stop_id})

      out_of_range_sibling =
        build(:stop, %{
          id: out_of_range_stop_id,
          name: "Stop 2",
          parent_station_id: parent_stop_id
        })

      RepositoryMock
      |> expect(:stops, 2, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:route_type) do
          [:light_rail, :heavy_rail, :bus, :ferry] ->
            ok_response([in_range_sibling], [parent, out_of_range_sibling])

          _ ->
            ok_response([])
        end
      end)

      conn = get(conn, "/api/nearby", %{latitude: 42.095734, longitude: -71.019708})

      assert %{"stop_ids" => [^in_range_stop_id, ^out_of_range_stop_id]} =
               json_response(conn, 200)
    end
  end

  describe "GET /api/nearby integration tests" do
    test "retrieves nearby stop and route info from the V3 API", %{conn: conn} do
      conn =
        get(conn, "/api/nearby", %{
          latitude: 42.281219333648,
          longitude: -71.17594685509955
        })

      %{"stop_ids" => stop_ids} = json_response(conn, 200)

      assert 21 = length(stop_ids)

      assert "67120" = List.first(stop_ids)
    end

    test "includes parent stop info from the V3 API", %{conn: conn} do
      conn = get(conn, "/api/nearby", %{latitude: 42.562535, longitude: -70.869116})

      assert %{
               "stop_ids" => [
                 "GB-0198",
                 "GB-0198-01",
                 "GB-0198-02",
                 "GB-0198-B3",
                 "GB-0198-B2"
               ]
             } = json_response(conn, 200)
    end
  end
end
