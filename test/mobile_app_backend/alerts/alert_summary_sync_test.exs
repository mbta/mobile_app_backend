defmodule MobileAppBackend.Alerts.AlertSummarySyncTest do
  @moduledoc """
  AlertSummary tests that swap global application env (e.g. `MBTAV3API.Repository`).
  They must not run concurrently with other tests, so they live here instead of in the async `AlertSummaryTest`.
  """
  use ExUnit.Case, async: false
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
  import Test.Support.Sigils
  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Notifications.Subscription

  setup :verify_on_exit!

  describe "summarizing/7" do
    test "trip specific station bypass" do
      now = ~B[2026-03-12 12:00:00]
      stop1 = build(:stop, name: "Ruggles")
      stop2 = build(:stop, name: "Back Bay")
      route = build(:route, type: :commuter_rail)
      pattern = build(:route_pattern, route_id: route.id)
      trip = build(:trip, headsign: "Stoughton", route_pattern_id: pattern.id)
      trip_id = trip.id

      alert =
        build(:alert,
          active_period: [
            %Alert.ActivePeriod{
              start: DateTime.add(now, -2, :hour),
              end: DateTime.add(now, 2, :hour)
            }
          ],
          effect: :station_closure,
          informed_entity: [
            %Alert.InformedEntity{stop: stop2.id, trip: trip.id},
            %Alert.InformedEntity{stop: stop1.id, trip: trip.id}
          ]
        )

      schedule =
        build(:schedule,
          trip_id: trip.id,
          departure_time: ~B[2026-03-12 12:13:00]
        )

      trip_time = schedule.departure_time
      route_type = route.type

      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

      RepositoryMock
      |> expect(:trips, fn [filter: [id: ^trip_id]], _ ->
        ok_response([trip])
      end)

      assert %AlertSummary.TripSpecific{
               trip_identity: %AlertSummary.TripSpecific.TripTo{
                 trip_time: ^trip_time,
                 route_type: ^route_type,
                 headsign: "Stoughton"
               },
               effect: :station_closure,
               effect_stops: ["Back Bay", "Ruggles"]
             } =
               AlertSummary.summarizing(
                 alert,
                 %Subscription{stop_id: stop1.id, direction_id: 0},
                 [pattern],
                 now,
                 [schedule],
                 %{
                   stops: %{stop1.id => stop1, stop2.id => stop2},
                   routes: %{route.id => route}
                 },
                 :notification
               )
    end
  end
end
