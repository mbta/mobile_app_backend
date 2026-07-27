defmodule MobileAppBackend.Alerts.SummaryEntityBuilderTest do
  use ExUnit.Case

  alias MBTAV3API.Alert.InformedEntity
  alias MobileAppBackend.Alerts.SummaryEntity
  alias MobileAppBackend.Alerts.SummaryEntityBuilder
  alias MobileAppBackend.Alerts.SummaryEntityBuilder.Combination
  alias MobileAppBackend.GlobalDataCache

  import Mox
  import Test.Support.Helpers
  import Test.Support.Sigils
  import MobileAppBackend.Factory

  setup do
    verify_on_exit!()
    Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
    MBTAV3API.RepositoryCache.delete_all()

    :ok
  end

  # make sure mocks are globally accessible, including from the PubSub genserver
  setup :set_mox_from_context

  describe "build_all/4" do
    test "build basic alert" do
      now = DateTime.now!("America/New_York")
      route_id = "Red"

      global = GlobalDataCache.get_data()

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [%InformedEntity{route: route_id}]
        )

      alert_id = alert.id

      assert %{
               ^alert_id => [
                 %SummaryEntity{
                   alert_id: ^alert_id,
                   route_id: ^route_id,
                   stop_id: nil,
                   trip_id: nil,
                   direction_id: nil,
                   summary: "Service suspended on Red Line"
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :notification)

      assert %{
               ^alert_id => [
                 %SummaryEntity{
                   alert_id: ^alert_id,
                   route_id: ^route_id,
                   stop_id: nil,
                   trip_id: nil,
                   direction_id: nil,
                   summary: "Service suspended on Red Line"
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :card)
    end

    test "build trip alert" do
      now = ~B[2026-06-03 12:00:00]

      global = GlobalDataCache.get_data()
      all_child_stops = MBTAV3API.Repository.stops(include: [:child_stops])

      stop_id = "place-wlsta"
      route_id = "Red"
      trip = build(:trip, route_id: route_id, stop_ids: [stop_id])
      trip_id = trip.id
      schedule = build(:schedule, trip_id: trip_id, route_id: route_id, stop_id: stop_id)

      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

      expect(RepositoryMock, :schedules, 2, fn
        [filter: [trip: [^trip_id]], include: [trip: :stops], sort: {:stop_sequence, :asc}], [] ->
          ok_response([schedule], [trip])
      end)

      stub(RepositoryMock, :stops, fn [include: [:child_stops]], [] -> all_child_stops end)

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [%InformedEntity{route: route_id, trip: trip_id}]
        )

      alert_id = alert.id

      assert %{
               ^alert_id => [
                 %SummaryEntity{
                   alert_id: ^alert_id,
                   route_id: ^route_id,
                   stop_id: nil,
                   trip_id: ^trip_id,
                   direction_id: 0,
                   summary:
                     "4:41 PM train from Wollaston is suspended tomorrow due to maintenance"
                 },
                 %MobileAppBackend.Alerts.SummaryEntity{
                   alert_id: ^alert_id,
                   direction_id: 1,
                   route_id: ^route_id,
                   stop_id: nil,
                   summary: "Service suspended on Red Line",
                   trip_id: ^trip_id
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :notification)

      assert %{
               ^alert_id => [
                 %SummaryEntity{
                   alert_id: ^alert_id,
                   route_id: ^route_id,
                   stop_id: nil,
                   trip_id: ^trip_id,
                   direction_id: 0,
                   summary: "This train is suspended tomorrow due to maintenance"
                 },
                 %MobileAppBackend.Alerts.SummaryEntity{
                   alert_id: ^alert_id,
                   direction_id: 1,
                   route_id: ^route_id,
                   stop_id: nil,
                   summary: "Service suspended on Red Line",
                   trip_id: ^trip_id
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :card)
    end

    test "build stop alert" do
      now = DateTime.now!("America/New_York")
      route_id = "Red"
      stop_id = "place-wlsta"

      global = GlobalDataCache.get_data()

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [%InformedEntity{stop: stop_id}]
        )

      alert_id = alert.id

      assert %{
               ^alert_id => [
                 %SummaryEntity{
                   alert_id: ^alert_id,
                   route_id: ^route_id,
                   stop_id: ^stop_id,
                   trip_id: nil,
                   direction_id: nil,
                   summary: "Service suspended at Wollaston"
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :notification)

      assert %{
               ^alert_id => [
                 %SummaryEntity{
                   alert_id: ^alert_id,
                   route_id: ^route_id,
                   stop_id: ^stop_id,
                   trip_id: nil,
                   direction_id: nil,
                   summary: "Service suspended at Wollaston"
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :card)
    end

    test "build route type alert" do
      now = DateTime.now!("America/New_York")

      global = GlobalDataCache.get_data()

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [%InformedEntity{route_type: 1}]
        )

      alert_id = alert.id

      assert %{
               ^alert_id => summary_entities
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :notification)

      assert [
               %SummaryEntity{
                 alert_id: ^alert_id,
                 route_id: "Blue",
                 stop_id: nil,
                 trip_id: nil,
                 direction_id: nil,
                 summary: "Service suspended on Blue Line"
               },
               %SummaryEntity{
                 alert_id: ^alert_id,
                 route_id: "Orange",
                 stop_id: nil,
                 trip_id: nil,
                 direction_id: nil,
                 summary: "Service suspended on Orange Line"
               },
               %SummaryEntity{
                 alert_id: ^alert_id,
                 route_id: "Red",
                 stop_id: nil,
                 trip_id: nil,
                 direction_id: nil,
                 summary: "Service suspended on Red Line"
               }
             ] = summary_entities |> Enum.sort_by(& &1.route_id)
    end
  end

  describe "relevant_combinations/3" do
    test "splits route entities into both directions" do
      global = GlobalDataCache.get_data()

      route_id = "Red"

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: route_id}
          ]
        )

      assert [
               %Combination{route: ^route_id, direction: 0},
               %Combination{route: ^route_id, direction: 1}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
               |> Enum.sort_by(&{&1.route, &1.stop, &1.trip, &1.direction})
    end

    test "splits stop entities into both directions" do
      global = GlobalDataCache.get_data()

      stop_id = "place-wlsta"

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [%InformedEntity{stop: stop_id}]
        )

      assert [
               %Combination{stop: ^stop_id, direction: 0},
               %Combination{stop: ^stop_id, direction: 1}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
               |> Enum.sort_by(&{&1.route, &1.stop, &1.trip, &1.direction})
    end

    test "trip entities set trip" do
      route_id = "Red"
      stop_id = "place-wlsta"
      trip = build(:trip)

      global = GlobalDataCache.get_data()

      trip_id = trip.id

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: route_id, stop: stop_id, trip: trip_id, direction_id: 1}
          ]
        )

      assert [%Combination{route: ^route_id, stop: ^stop_id, trip: ^trip_id, direction: 1}] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
    end

    test "creates a combination for every route with a route_type entity" do
      global = GlobalDataCache.get_data()

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route_type: 1}
          ]
        )

      assert [
               %Combination{route: "Blue"},
               %Combination{route: "Orange"},
               %Combination{route: "Red"}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
               |> Enum.sort_by(&{&1.route, &1.stop, &1.trip, &1.direction})
    end

    test "filters identical combinations" do
      global = GlobalDataCache.get_data()

      route_id = "Red"
      stop_id = "place-wlsta"
      child_stop_id = "70099"

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: route_id, stop: stop_id},
            %InformedEntity{route: route_id, stop: child_stop_id}
          ]
        )

      assert [
               %Combination{route: ^route_id, stop: ^stop_id, direction: 0},
               %Combination{route: ^route_id, stop: ^stop_id, direction: 1}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
               |> Enum.sort_by(&{&1.route, &1.stop, &1.trip, &1.direction})
    end

    test "filters combinations covered by another stop wildcard" do
      global = GlobalDataCache.get_data()

      stop_id = "place-wlsta"
      route_id = "Red"

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: route_id, stop: nil},
            %InformedEntity{route: route_id, stop: stop_id}
          ]
        )

      assert [
               %Combination{route: ^route_id, stop: nil, direction: 0},
               %Combination{route: ^route_id, stop: nil, direction: 1}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
               |> Enum.sort_by(&{&1.route, &1.stop, &1.trip, &1.direction})
    end

    test "filters combinations covered by another route wildcard" do
      global = GlobalDataCache.get_data()

      route_id = "Red"
      stop_id = "place-wlsta"

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: nil, stop: stop_id},
            %InformedEntity{route: route_id, stop: stop_id}
          ]
        )

      assert [
               %Combination{route: nil, stop: ^stop_id, direction: 0},
               %Combination{route: nil, stop: ^stop_id, direction: 1}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
               |> Enum.sort_by(&{&1.route, &1.stop, &1.trip, &1.direction})
    end

    test "filters combinations covered by another trip wildcard" do
      stop = build(:stop, parent_station_id: nil)
      child_stop = build(:stop, parent_station_id: stop.id)
      route = build(:route, type: :heavy_rail, long_name: "Red Line")
      trip = build(:trip, route_id: route.id, stop_ids: [child_stop.id])

      global = GlobalDataCache.get_data()

      route_id = "Red"
      stop_id = "place-wlsta"
      trip_id = trip.id

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: nil, stop: stop_id, trip: nil},
            %InformedEntity{route: route_id, stop: stop_id, trip: trip_id, direction_id: 1}
          ]
        )

      assert [
               %Combination{route: nil, stop: ^stop_id, direction: 0},
               %Combination{route: nil, stop: ^stop_id, direction: 1}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
               |> Enum.sort_by(&{&1.route, &1.stop, &1.trip, &1.direction})
    end
  end

  describe "dedup_summaries/1" do
    test "removes duplicate summaries" do
      assert [
               %SummaryEntity{
                 alert_id: "alert",
                 route_id: "route",
                 stop_id: "stop1",
                 trip_id: nil,
                 direction_id: nil,
                 summary: "identical summary"
               },
               %SummaryEntity{
                 alert_id: "alert",
                 route_id: "route",
                 stop_id: "stop2",
                 trip_id: nil,
                 direction_id: 0,
                 summary: "different summary 1"
               },
               %SummaryEntity{
                 alert_id: "alert",
                 route_id: "route",
                 stop_id: "stop2",
                 trip_id: nil,
                 direction_id: 1,
                 summary: "different summary 2"
               },
               %SummaryEntity{
                 alert_id: "alert",
                 route_id: "route",
                 stop_id: "stop3",
                 trip_id: nil,
                 direction_id: nil,
                 summary: "nil direction summary"
               }
             ] =
               SummaryEntityBuilder.dedup_summaries([
                 %SummaryEntity{
                   alert_id: "alert",
                   route_id: "route",
                   stop_id: "stop1",
                   trip_id: nil,
                   direction_id: 0,
                   summary: "identical summary"
                 },
                 %SummaryEntity{
                   alert_id: "alert",
                   route_id: "route",
                   stop_id: "stop1",
                   trip_id: nil,
                   direction_id: 1,
                   summary: "identical summary"
                 },
                 %SummaryEntity{
                   alert_id: "alert",
                   route_id: "route",
                   stop_id: "stop2",
                   trip_id: nil,
                   direction_id: 0,
                   summary: "different summary 1"
                 },
                 %SummaryEntity{
                   alert_id: "alert",
                   route_id: "route",
                   stop_id: "stop2",
                   trip_id: nil,
                   direction_id: 1,
                   summary: "different summary 2"
                 },
                 %SummaryEntity{
                   alert_id: "alert",
                   route_id: "route",
                   stop_id: "stop3",
                   trip_id: nil,
                   direction_id: nil,
                   summary: "nil direction summary"
                 }
               ])
    end
  end
end
