defmodule OpenTripPlannerClient.HttpTest do
  @moduledoc """
  Tests for OpenTripPlanner that require overriding the OTP host or making
  external requests.

  We pull these into a separate module so that the main body of tests can
  remain async: true.

  """
  use ExUnit.Case
  import OpenTripPlannerClient
  alias OpenTripPlannerClient.{ItineraryTag, NamedPosition}
  import Plug.Conn, only: [send_resp: 3]

  setup context do
    if context[:external] do
      :ok
    else
      bypass = Bypass.open()
      host = "http://localhost:#{bypass.port}"
      old_otp_url = Application.get_env(:mobile_app_backend, :otp_url)
      old_level = Logger.level()

      on_exit(fn ->
        Application.put_env(:mobile_app_backend, :otp_url, old_otp_url)
        Logger.configure(level: old_level)
      end)

      Application.put_env(:mobile_app_backend, :otp_url, host)
      Logger.configure(level: :info)

      {:ok, %{bypass: bypass}}
    end
  end

  describe "plan/3 with fixture data" do
    @fixture File.read!("test/fixture/north_station_to_park_plaza.json")

    test "can apply tags", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(:ok, ~s({"data":#{@fixture}}))
      end)

      {:ok, itineraries} =
        plan(
          %NamedPosition{
            name: "North Station",
            stop_id: "place-north",
            latitude: 42.365551,
            longitude: -71.061251
          },
          %NamedPosition{latitude: 42.348777, longitude: -71.066481},
          tags: [
            ItineraryTag.EarliestArrival,
            ItineraryTag.LeastWalking,
            ItineraryTag.ShortestTrip
          ]
        )

      tags = itineraries |> Enum.map(&Enum.sort(&1.tags))

      assert tags == [
               [:earliest_arrival, :least_walking, :shortest_trip],
               [:least_walking],
               [:least_walking]
             ]
    end
  end

  describe "plan/3 with real OTP" do
    @describetag :external

    test "can make a basic plan with OTP" do
      north_station = %NamedPosition{
        name: "North Station",
        stop_id: "place-north",
        latitude: 42.365551,
        longitude: -71.061251
      }

      boylston = %NamedPosition{latitude: 42.348777, longitude: -71.066481}

      assert {:ok, itineraries} =
               plan(north_station, boylston, depart_at: DateTime.utc_now())

      refute itineraries == []
    end
  end

  describe "error handling/logging" do
    @tag :capture_log
    test "HTTP errors are converted to error tuples", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        send_resp(conn, 500, "{}")
      end)

      assert {:error, _} =
               plan(
                 %NamedPosition{latitude: 1, longitude: 1},
                 %NamedPosition{latitude: 2, longitude: 2},
                 depart_at: DateTime.utc_now()
               )
    end

    @tag :capture_log
    test "connection errors are converted to error tuples", %{bypass: bypass} do
      Bypass.down(bypass)

      assert {:error, _} =
               plan(
                 %NamedPosition{latitude: 1, longitude: 1},
                 %NamedPosition{latitude: 2, longitude: 2},
                 depart_at: DateTime.utc_now()
               )
    end
  end
end
