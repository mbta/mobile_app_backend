defmodule MobileAppBackend.Alerts.AlertUtilTest do
  use MobileAppBackend.DataCase, async: false
  use HttpStub.Case

  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers

  alias MBTAV3API.Alert
  alias MBTAV3API.Repository
  alias MobileAppBackend.Alerts.AlertUtil

  setup :verify_on_exit!

  describe "fetch_schedules_for_alert/2" do
    test "returns {nil, nil} when alert has no trip ids" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
          effect: :suspension,
          informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}]
        )

      reassign_env(:mobile_app_backend, Repository, RepositoryMock)

      RepositoryMock |> expect(:schedules, 0, fn _, _ -> :err end)

      assert {nil, nil} = AlertUtil.fetch_schedules_for_alert(alert, now)
    end

    test "fetches schedules for a single trip on today's service date" do
      now = DateTime.now!("America/New_York")
      service_day = Util.DateTime.datetime_to_gtfs(now)

      trip = build(:trip, route_id: "Red", stop_ids: ["place-sstat"])
      trip_id = trip.id

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{activities: [:board], route: "Red", trip: trip_id}
          ]
        )

      schedule = build(:schedule, trip_id: trip_id)

      reassign_env(:mobile_app_backend, Repository, RepositoryMock)

      RepositoryMock
      |> expect(
        :schedules,
        fn [
             filter: [trip: [^trip_id], date: ^service_day],
             include: [trip: :stops],
             sort: {:stop_sequence, :asc},
             fields: [stop: []]
           ],
           _ ->
          ok_response([schedule], [trip])
        end
      )

      assert {[^schedule], %{^trip_id => ^trip}} =
               AlertUtil.fetch_schedules_for_alert(alert, now)
    end

    test "fetches schedules across today and tomorrow when trip missing today" do
      now = DateTime.now!("America/New_York")
      today = Util.DateTime.datetime_to_gtfs(now)
      tomorrow = Date.add(today, 1)

      trip_1 = build(:trip, route_id: "Red", stop_ids: ["place-sstat"])
      trip_1_id = trip_1.id
      trip_2 = build(:trip, route_id: "Red", stop_ids: ["place-sstat"])
      trip_2_id = trip_2.id

      alert =
        build(:alert,
          active_period: [
            %Alert.ActivePeriod{start: DateTime.add(now, -1), end: DateTime.add(now, 3, :day)}
          ],
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{activities: [:board], route: "Red", trip: trip_1_id},
            %Alert.InformedEntity{activities: [:board], route: "Red", trip: trip_2_id}
          ]
        )

      schedule_1 = build(:schedule, trip_id: trip_1_id)
      schedule_2 = build(:schedule, trip_id: trip_2_id)

      reassign_env(:mobile_app_backend, Repository, RepositoryMock)

      RepositoryMock
      |> expect(
        :schedules,
        fn [
             filter: [trip: [^trip_1_id, ^trip_2_id], date: ^today],
             include: [trip: :stops],
             sort: {:stop_sequence, :asc},
             fields: [stop: []]
           ],
           _ ->
          ok_response([schedule_1], [trip_1])
        end
      )
      |> expect(
        :schedules,
        fn [
             filter: [trip: [^trip_2_id], date: ^tomorrow],
             include: [trip: :stops],
             sort: {:stop_sequence, :asc},
             fields: [stop: []]
           ],
           _ ->
          ok_response([schedule_2], [trip_2])
        end
      )

      assert {schedules, trips} = AlertUtil.fetch_schedules_for_alert(alert, now)
      assert schedules == [schedule_1, schedule_2]
      assert trips == %{trip_1_id => trip_1, trip_2_id => trip_2}
    end
  end

  describe "fetch_trips_for_alerts/2" do
    test "returns [] when no alerts reference a trip" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          effect: :suspension,
          informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}]
        )

      assert [] = AlertUtil.fetch_trips_for_alerts([alert], now)
    end

    test "fetches trips for alerts on today's service date" do
      now = DateTime.now!("America/New_York")
      service_day = Util.DateTime.datetime_to_gtfs(now)

      trip = build(:trip, route_id: "Red", stop_ids: ["place-sstat"])
      trip_id = trip.id

      alert =
        build(:alert,
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{activities: [:board], route: "Red", trip: trip_id}
          ]
        )

      reassign_env(:mobile_app_backend, Repository, RepositoryMock)

      RepositoryMock
      |> expect(
        :trips,
        fn [filter: [id: [^trip_id], date: ^service_day], include: [:stops], fields: [stop: []]],
           _ ->
          ok_response([trip], %{})
        end
      )

      assert [^trip] = AlertUtil.fetch_trips_for_alerts([alert], now)
    end

    test "fetches trips across today and tomorrow when a trip is missing today" do
      now = DateTime.now!("America/New_York")
      today = Util.DateTime.datetime_to_gtfs(now)
      tomorrow = Date.add(today, 1)

      trip_1 = build(:trip, route_id: "Red", stop_ids: ["place-sstat"])
      trip_1_id = trip_1.id
      trip_2 = build(:trip, route_id: "Red", stop_ids: ["place-sstat"])
      trip_2_id = trip_2.id

      alert1 =
        build(:alert,
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{activities: [:board], route: "Red", trip: trip_1_id}
          ]
        )

      alert2 =
        build(:alert,
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{activities: [:board], route: "Red", trip: trip_2_id}
          ]
        )

      reassign_env(:mobile_app_backend, Repository, RepositoryMock)

      RepositoryMock
      |> expect(
        :trips,
        fn [
             filter: [id: [^trip_1_id, ^trip_2_id], date: ^today],
             include: [:stops],
             fields: [stop: []]
           ],
           _ ->
          ok_response([trip_1], %{})
        end
      )
      |> expect(
        :trips,
        fn [filter: [id: [^trip_2_id], date: ^tomorrow], include: [:stops], fields: [stop: []]],
           _ ->
          ok_response([trip_2], %{})
        end
      )

      assert [^trip_1, ^trip_2] = AlertUtil.fetch_trips_for_alerts([alert1, alert2], now)
    end
  end
end
