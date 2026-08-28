defmodule MobileAppBackend.Alerts.SummaryEntityBuilderTest do
  use ExUnit.Case

  alias MBTAV3API.Alert.ActivePeriod
  alias MBTAV3API.Alert.InformedEntity
  alias MBTAV3API.RoutePattern
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
                   route_id: nil,
                   stop_id: nil,
                   trip_id: nil,
                   direction_id: nil,
                   summary: "Service suspended on Red Line due to maintenance"
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :notification)

      assert %{
               ^alert_id => [
                 %SummaryEntity{
                   route_id: nil,
                   stop_id: nil,
                   trip_id: nil,
                   direction_id: nil,
                   summary: "**Service suspended** on **Red Line** due to maintenance"
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :card)
    end

    test "build trip alert" do
      now = ~B[2026-06-03 12:00:00]

      global = GlobalDataCache.get_data()
      all_child_stops = MBTAV3API.Repository.stops(include: [:child_stops])

      stops = [
        "place-brntn",
        "place-qamnl",
        "place-qnctr",
        "place-wlsta",
        "place-nqncy",
        "place-jfk",
        "place-andrw",
        "place-brdwy",
        "place-sstat",
        "place-dwnxg",
        "place-pktrm",
        "place-chmnl",
        "place-knncl",
        "place-cntsq",
        "place-harsq",
        "place-portr",
        "place-davis",
        "place-alfcl"
      ]

      route_id = "Red"

      trip =
        build(:trip,
          direction_id: 1,
          route_id: route_id,
          route_pattern_id: "Red-3-1",
          stop_ids: stops
        )

      trip_id = trip.id

      schedules =
        for {stop, index} <- Enum.with_index(stops) do
          build(:schedule,
            departure_time: DateTime.add(now, index, :minute),
            trip_id: trip_id,
            route_id: route_id,
            stop_id: stop
          )
        end

      service_date = Util.DateTime.datetime_to_gtfs(now)

      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

      expect(RepositoryMock, :schedules, 2, fn
        [
          filter: [trip: [^trip_id], date: ^service_date],
          include: [trip: :stops],
          sort: {:stop_sequence, :asc},
          fields: [stop: []]
        ],
        [] ->
          ok_response(schedules, [trip])
      end)

      stub(RepositoryMock, :stops, fn [include: [:child_stops]], [] -> all_child_stops end)

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: route_id, trip: trip_id, direction_id: trip.direction_id}
          ],
          active_period: [
            %ActivePeriod{
              start: now |> DateTime.add(-1, :hour),
              end: DateTime.add(now, 3, :day)
            }
          ]
        )

      alert_id = alert.id

      assert %{^alert_id => entities} =
               SummaryEntityBuilder.build_all([alert], now, "en", global, :notification)

      assert Enum.sort_by(entities, &{&1.route_id, &1.stop_id, &1.direction_id, &1.trip_id}) == [
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-alfcl",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:17 PM train from Alewife is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-andrw",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:06 PM train from Andrew is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-brdwy",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:07 PM train from Broadway is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-brntn",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:00 PM train from Braintree is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-chmnl",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:11 PM train from Charles/MGH is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-cntsq",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:13 PM train from Central is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-davis",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:16 PM train from Davis is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-dwnxg",
                 direction_id: nil,
                 trip_id: nil,
                 summary:
                   "12:09 PM train from Downtown Crossing is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-harsq",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:14 PM train from Harvard is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-jfk",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:05 PM train from JFK/UMass is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-knncl",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:12 PM train from Kendall/MIT is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-nqncy",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:04 PM train from North Quincy is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-pktrm",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:10 PM train from Park Street is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-portr",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:15 PM train from Porter is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-qamnl",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:01 PM train from Quincy Adams is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-qnctr",
                 direction_id: nil,
                 trip_id: nil,
                 summary:
                   "12:02 PM train from Quincy Center is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-sstat",
                 direction_id: nil,
                 trip_id: nil,
                 summary:
                   "12:08 PM train from South Station is suspended today due to maintenance"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: "place-wlsta",
                 direction_id: nil,
                 trip_id: nil,
                 summary: "12:03 PM train from Wollaston is suspended today due to maintenance"
               }
             ]

      assert %{^alert_id => entities} =
               SummaryEntityBuilder.build_all([alert], now, "en", global, :card)

      assert Enum.sort_by(entities, &{&1.route_id, &1.stop_id, &1.direction_id, &1.trip_id}) == [
               %SummaryEntity{
                 route_id: nil,
                 stop_id: nil,
                 direction_id: nil,
                 trip_id: nil,
                 summary: "This train is suspended today due to maintenance"
               }
             ]
    end

    # This is the current behavior, which I think we'll want to change, but leaving it here
    # so we have a test to make sure the future change works as expected.
    test "build trip alert for a trip not scheduled today" do
      now = ~B[2026-06-03 12:00:00]

      global = GlobalDataCache.get_data()
      all_child_stops = MBTAV3API.Repository.stops(include: [:child_stops])

      stops = [
        "place-brntn",
        "place-qamnl",
        "place-qnctr",
        "place-wlsta",
        "place-nqncy",
        "place-jfk",
        "place-andrw",
        "place-brdwy",
        "place-sstat",
        "place-dwnxg",
        "place-pktrm",
        "place-chmnl",
        "place-knncl",
        "place-cntsq",
        "place-harsq",
        "place-portr",
        "place-davis",
        "place-alfcl"
      ]

      route_id = "Red"

      trip =
        build(:trip,
          direction_id: 1,
          route_id: route_id,
          route_pattern_id: "Red-3-1",
          stop_ids: stops
        )

      trip_id = trip.id

      tomorrow = DateTime.add(now, 1, :day)
      service_day_tomorrow = Util.DateTime.datetime_to_gtfs(tomorrow)

      schedules =
        for {stop, index} <- Enum.with_index(stops) do
          build(:schedule,
            departure_time: DateTime.add(tomorrow, index, :minute),
            trip_id: trip_id,
            route_id: route_id,
            stop_id: stop
          )
        end

      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

      RepositoryMock
      |> expect(:schedules, 2, fn
        [
          filter: [trip: [^trip_id], date: ^service_day_tomorrow],
          include: [trip: :stops],
          sort: {:stop_sequence, :asc},
          fields: [stop: []]
        ],
        [] ->
          ok_response(schedules, [trip])
      end)

      stub(RepositoryMock, :stops, fn [include: [:child_stops]], [] -> all_child_stops end)

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: route_id, trip: trip_id, direction_id: trip.direction_id}
          ],
          active_period: [
            %ActivePeriod{
              start: now |> DateTime.add(1, :day) |> DateTime.add(-1, :hour),
              end: DateTime.add(now, 3, :day)
            }
          ]
        )

      alert_id = alert.id

      assert %{^alert_id => entities} =
               SummaryEntityBuilder.build_all([alert], now, "en", global, :notification)

      assert Enum.sort_by(entities, &{&1.route_id, &1.stop_id, &1.direction_id, &1.trip_id}) == [
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-alfcl",
                 summary: "12:17 PM train from Alewife is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-andrw",
                 summary: "12:06 PM train from Andrew is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-brdwy",
                 summary: "12:07 PM train from Broadway is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-brntn",
                 summary:
                   "12:00 PM train from Braintree is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-chmnl",
                 summary:
                   "12:11 PM train from Charles/MGH is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-cntsq",
                 summary: "12:13 PM train from Central is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-davis",
                 summary: "12:16 PM train from Davis is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-dwnxg",
                 summary:
                   "12:09 PM train from Downtown Crossing is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-harsq",
                 summary: "12:14 PM train from Harvard is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-jfk",
                 summary:
                   "12:05 PM train from JFK/UMass is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-knncl",
                 summary:
                   "12:12 PM train from Kendall/MIT is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-nqncy",
                 summary:
                   "12:04 PM train from North Quincy is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-pktrm",
                 summary:
                   "12:10 PM train from Park Street is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-portr",
                 summary: "12:15 PM train from Porter is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-qamnl",
                 summary:
                   "12:01 PM train from Quincy Adams is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-qnctr",
                 summary:
                   "12:02 PM train from Quincy Center is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-sstat",
                 summary:
                   "12:08 PM train from South Station is suspended tomorrow due to maintenance",
                 trip_id: nil
               },
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: "place-wlsta",
                 summary:
                   "12:03 PM train from Wollaston is suspended tomorrow due to maintenance",
                 trip_id: nil
               }
             ]

      assert %{^alert_id => entities} =
               SummaryEntityBuilder.build_all([alert], now, "en", global, :card)

      assert Enum.sort_by(entities, &{&1.route_id, &1.stop_id, &1.direction_id, &1.trip_id}) == [
               %MobileAppBackend.Alerts.SummaryEntity{
                 direction_id: nil,
                 route_id: nil,
                 stop_id: nil,
                 summary: "This train is suspended tomorrow due to maintenance",
                 trip_id: nil
               }
             ]
    end

    test "build stop alert" do
      now = DateTime.now!("America/New_York")
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
                   route_id: nil,
                   stop_id: nil,
                   trip_id: nil,
                   direction_id: nil,
                   summary: "Service suspended at Wollaston due to maintenance"
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :notification)

      assert %{
               ^alert_id => [
                 %SummaryEntity{
                   route_id: nil,
                   stop_id: nil,
                   trip_id: nil,
                   direction_id: nil,
                   summary: "**Service suspended** at **Wollaston** due to maintenance"
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
          informed_entity: [%InformedEntity{route_type: :heavy_rail}]
        )

      alert_id = alert.id

      assert %{
               ^alert_id => summary_entities
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :notification)

      assert [
               %SummaryEntity{
                 route_id: "Blue",
                 stop_id: nil,
                 trip_id: nil,
                 direction_id: nil,
                 summary: "Service suspended on Blue Line due to maintenance"
               },
               %SummaryEntity{
                 route_id: "Orange",
                 stop_id: nil,
                 trip_id: nil,
                 direction_id: nil,
                 summary: "Service suspended on Orange Line due to maintenance"
               },
               %SummaryEntity{
                 route_id: "Red",
                 stop_id: nil,
                 trip_id: nil,
                 direction_id: nil,
                 summary: "Service suspended on Red Line due to maintenance"
               }
             ] =
               summary_entities
               |> Enum.sort_by(&{&1.route_id, &1.stop_id, &1.direction_id, &1.trip_id})
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

      expected_combinations =
        for stop <- [
              "alfcl",
              "andrw",
              "asmnl",
              "brdwy",
              "brntn",
              "chmnl",
              "cntsq",
              "davis",
              "dwnxg",
              "fldcr",
              "harsq",
              "jfk",
              "knncl",
              "nqncy",
              "pktrm",
              "portr",
              "qamnl",
              "qnctr",
              "shmnl",
              "smmnl",
              "sstat",
              "wlsta"
            ],
            direction <- [0, 1] do
          %Combination{
            route: "Red",
            stop: "place-" <> stop,
            direction: direction,
            trip: nil,
            patterns:
              RoutePattern.get_relevant_patterns(route_id, "place-" <> stop, direction, global)
          }
        end

      assert SummaryEntityBuilder.relevant_combinations(alert, {%{}, %{}, global})
             |> Enum.sort_by(&{&1.route, &1.stop, &1.direction, &1.trip}) ==
               expected_combinations
    end

    test "splits stop entities into both directions" do
      global = GlobalDataCache.get_data()

      route_id = "Red"
      stop_id = "place-wlsta"

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [%InformedEntity{stop: stop_id}]
        )

      expected_combinations =
        for stop <- [
              "alfcl",
              "andrw",
              "asmnl",
              "brdwy",
              "brntn",
              "chmnl",
              "cntsq",
              "davis",
              "dwnxg",
              "fldcr",
              "harsq",
              "jfk",
              "knncl",
              "nqncy",
              "pktrm",
              "portr",
              "qamnl",
              "qnctr",
              "shmnl",
              "smmnl",
              "sstat",
              "wlsta"
            ],
            direction <- [0, 1] do
          %Combination{
            route: route_id,
            stop: "place-" <> stop,
            direction: direction,
            trip: nil,
            patterns:
              RoutePattern.get_relevant_patterns(route_id, "place-" <> stop, direction, global)
          }
        end

      assert SummaryEntityBuilder.relevant_combinations(alert, {global.stops, %{}, global})
             |> Enum.sort_by(&{&1.route, &1.stop, &1.direction, &1.trip}) == expected_combinations
    end

    test "trip entities set trip" do
      route_id = "Red"
      stop_id = "place-wlsta"

      trip =
        build(:trip,
          direction_id: 1,
          route_pattern_id: "Red-3-1",
          stop_ids: [
            "place-brntn",
            "place-qamnl",
            "place-qnctr",
            "place-wlsta",
            "place-nqncy",
            "place-jfk",
            "place-andrw",
            "place-brdwy",
            "place-sstat",
            "place-dwnxg",
            "place-pktrm",
            "place-chmnl",
            "place-knncl",
            "place-cntsq",
            "place-harsq",
            "place-portr",
            "place-davis",
            "place-alfcl"
          ]
        )

      global = GlobalDataCache.get_data()

      pattern = global.route_patterns[trip.route_pattern_id]
      trip_id = trip.id

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: route_id, stop: stop_id, trip: trip_id}
          ]
        )

      expected_combinations =
        for stop <- [
              "alfcl",
              "andrw",
              "brdwy",
              "brntn",
              "chmnl",
              "cntsq",
              "davis",
              "dwnxg",
              "harsq",
              "jfk",
              "knncl",
              "nqncy",
              "pktrm",
              "portr",
              "qamnl",
              "qnctr",
              "sstat",
              "wlsta"
            ] do
          %Combination{
            route: route_id,
            stop: "place-" <> stop,
            direction: 1,
            trip: trip.id,
            patterns: [pattern]
          }
        end

      assert SummaryEntityBuilder.relevant_combinations(alert, {%{}, %{trip.id => trip}, global})
             |> Enum.sort_by(&{&1.route, &1.stop, &1.direction, &1.trip}) ==
               expected_combinations
    end

    test "creates a combination for every route with a route_type entity" do
      global = GlobalDataCache.get_data()

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route_type: :heavy_rail}
          ]
        )

      assert [
               %Combination{route: "Blue", stop: "place-aport", direction: 0},
               %Combination{route: "Blue", stop: "place-aport", direction: 1},
               %Combination{route: "Blue", stop: "place-aqucl", direction: 0},
               %Combination{route: "Blue", stop: "place-aqucl", direction: 1},
               %Combination{route: "Blue", stop: "place-bmmnl", direction: 0},
               %Combination{route: "Blue", stop: "place-bmmnl", direction: 1},
               %Combination{route: "Blue", stop: "place-bomnl", direction: 0},
               %Combination{route: "Blue", stop: "place-bomnl", direction: 1},
               %Combination{route: "Blue", stop: "place-gover", direction: 0},
               %Combination{route: "Blue", stop: "place-gover", direction: 1},
               %Combination{route: "Blue", stop: "place-mvbcl", direction: 0},
               %Combination{route: "Blue", stop: "place-mvbcl", direction: 1},
               %Combination{route: "Blue", stop: "place-orhte", direction: 0},
               %Combination{route: "Blue", stop: "place-orhte", direction: 1},
               %Combination{route: "Blue", stop: "place-rbmnl", direction: 0},
               %Combination{route: "Blue", stop: "place-rbmnl", direction: 1},
               %Combination{route: "Blue", stop: "place-sdmnl", direction: 0},
               %Combination{route: "Blue", stop: "place-sdmnl", direction: 1},
               %Combination{route: "Blue", stop: "place-state", direction: 0},
               %Combination{route: "Blue", stop: "place-state", direction: 1},
               %Combination{route: "Blue", stop: "place-wimnl", direction: 0},
               %Combination{route: "Blue", stop: "place-wimnl", direction: 1},
               %Combination{route: "Blue", stop: "place-wondl", direction: 0},
               %Combination{route: "Blue", stop: "place-wondl", direction: 1},
               %Combination{route: "Orange", stop: "place-astao", direction: 0},
               %Combination{route: "Orange", stop: "place-astao", direction: 1},
               %Combination{route: "Orange", stop: "place-bbsta", direction: 0},
               %Combination{route: "Orange", stop: "place-bbsta", direction: 1},
               %Combination{route: "Orange", stop: "place-ccmnl", direction: 0},
               %Combination{route: "Orange", stop: "place-ccmnl", direction: 1},
               %Combination{route: "Orange", stop: "place-chncl", direction: 0},
               %Combination{route: "Orange", stop: "place-chncl", direction: 1},
               %Combination{route: "Orange", stop: "place-dwnxg", direction: 0},
               %Combination{route: "Orange", stop: "place-dwnxg", direction: 1},
               %Combination{route: "Orange", stop: "place-forhl", direction: 0},
               %Combination{route: "Orange", stop: "place-forhl", direction: 1},
               %Combination{route: "Orange", stop: "place-grnst", direction: 0},
               %Combination{route: "Orange", stop: "place-grnst", direction: 1},
               %Combination{route: "Orange", stop: "place-haecl", direction: 0},
               %Combination{route: "Orange", stop: "place-haecl", direction: 1},
               %Combination{route: "Orange", stop: "place-jaksn", direction: 0},
               %Combination{route: "Orange", stop: "place-jaksn", direction: 1},
               %Combination{route: "Orange", stop: "place-masta", direction: 0},
               %Combination{route: "Orange", stop: "place-masta", direction: 1},
               %Combination{route: "Orange", stop: "place-mlmnl", direction: 0},
               %Combination{route: "Orange", stop: "place-mlmnl", direction: 1},
               %Combination{route: "Orange", stop: "place-north", direction: 0},
               %Combination{route: "Orange", stop: "place-north", direction: 1},
               %Combination{route: "Orange", stop: "place-ogmnl", direction: 0},
               %Combination{route: "Orange", stop: "place-ogmnl", direction: 1},
               %Combination{route: "Orange", stop: "place-rcmnl", direction: 0},
               %Combination{route: "Orange", stop: "place-rcmnl", direction: 1},
               %Combination{route: "Orange", stop: "place-rugg", direction: 0},
               %Combination{route: "Orange", stop: "place-rugg", direction: 1},
               %Combination{route: "Orange", stop: "place-sbmnl", direction: 0},
               %Combination{route: "Orange", stop: "place-sbmnl", direction: 1},
               %Combination{route: "Orange", stop: "place-state", direction: 0},
               %Combination{route: "Orange", stop: "place-state", direction: 1},
               %Combination{route: "Orange", stop: "place-sull", direction: 0},
               %Combination{route: "Orange", stop: "place-sull", direction: 1},
               %Combination{route: "Orange", stop: "place-tumnl", direction: 0},
               %Combination{route: "Orange", stop: "place-tumnl", direction: 1},
               %Combination{route: "Orange", stop: "place-welln", direction: 0},
               %Combination{route: "Orange", stop: "place-welln", direction: 1},
               %Combination{route: "Red", stop: "place-alfcl", direction: 0},
               %Combination{route: "Red", stop: "place-alfcl", direction: 1},
               %Combination{route: "Red", stop: "place-andrw", direction: 0},
               %Combination{route: "Red", stop: "place-andrw", direction: 1},
               %Combination{route: "Red", stop: "place-asmnl", direction: 0},
               %Combination{route: "Red", stop: "place-asmnl", direction: 1},
               %Combination{route: "Red", stop: "place-brdwy", direction: 0},
               %Combination{route: "Red", stop: "place-brdwy", direction: 1},
               %Combination{route: "Red", stop: "place-brntn", direction: 0},
               %Combination{route: "Red", stop: "place-brntn", direction: 1},
               %Combination{route: "Red", stop: "place-chmnl", direction: 0},
               %Combination{route: "Red", stop: "place-chmnl", direction: 1},
               %Combination{route: "Red", stop: "place-cntsq", direction: 0},
               %Combination{route: "Red", stop: "place-cntsq", direction: 1},
               %Combination{route: "Red", stop: "place-davis", direction: 0},
               %Combination{route: "Red", stop: "place-davis", direction: 1},
               %Combination{route: "Red", stop: "place-dwnxg", direction: 0},
               %Combination{route: "Red", stop: "place-dwnxg", direction: 1},
               %Combination{route: "Red", stop: "place-fldcr", direction: 0},
               %Combination{route: "Red", stop: "place-fldcr", direction: 1},
               %Combination{route: "Red", stop: "place-harsq", direction: 0},
               %Combination{route: "Red", stop: "place-harsq", direction: 1},
               %Combination{route: "Red", stop: "place-jfk", direction: 0},
               %Combination{route: "Red", stop: "place-jfk", direction: 1},
               %Combination{route: "Red", stop: "place-knncl", direction: 0},
               %Combination{route: "Red", stop: "place-knncl", direction: 1},
               %Combination{route: "Red", stop: "place-nqncy", direction: 0},
               %Combination{route: "Red", stop: "place-nqncy", direction: 1},
               %Combination{route: "Red", stop: "place-pktrm", direction: 0},
               %Combination{route: "Red", stop: "place-pktrm", direction: 1},
               %Combination{route: "Red", stop: "place-portr", direction: 0},
               %Combination{route: "Red", stop: "place-portr", direction: 1},
               %Combination{route: "Red", stop: "place-qamnl", direction: 0},
               %Combination{route: "Red", stop: "place-qamnl", direction: 1},
               %Combination{route: "Red", stop: "place-qnctr", direction: 0},
               %Combination{route: "Red", stop: "place-qnctr", direction: 1},
               %Combination{route: "Red", stop: "place-shmnl", direction: 0},
               %Combination{route: "Red", stop: "place-shmnl", direction: 1},
               %Combination{route: "Red", stop: "place-smmnl", direction: 0},
               %Combination{route: "Red", stop: "place-smmnl", direction: 1},
               %Combination{route: "Red", stop: "place-sstat", direction: 0},
               %Combination{route: "Red", stop: "place-sstat", direction: 1},
               %Combination{route: "Red", stop: "place-wlsta", direction: 0},
               %Combination{route: "Red", stop: "place-wlsta", direction: 1}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, {%{}, %{}, global})
               |> Enum.sort_by(&{&1.route, &1.stop, &1.direction, &1.trip})
    end
  end

  describe "dedup_summaries/1" do
    test "removes duplicate summaries" do
      assert [
               %SummaryEntity{
                 route_id: nil,
                 stop_id: nil,
                 trip_id: nil,
                 direction_id: 0,
                 summary: "direction 0 summary"
               },
               %SummaryEntity{
                 route_id: nil,
                 stop_id: nil,
                 trip_id: nil,
                 direction_id: 1,
                 summary: "direction 1 summary"
               }
             ] =
               SummaryEntityBuilder.dedup_summaries([
                 %SummaryEntity{
                   route_id: "route",
                   stop_id: "stop1",
                   trip_id: nil,
                   direction_id: 0,
                   summary: "direction 0 summary"
                 },
                 %SummaryEntity{
                   route_id: "route",
                   stop_id: "stop1",
                   trip_id: nil,
                   direction_id: 1,
                   summary: "direction 1 summary"
                 },
                 %SummaryEntity{
                   route_id: "route",
                   stop_id: "stop2",
                   trip_id: nil,
                   direction_id: 0,
                   summary: "direction 0 summary"
                 },
                 %SummaryEntity{
                   route_id: "route",
                   stop_id: "stop2",
                   trip_id: nil,
                   direction_id: 1,
                   summary: "direction 1 summary"
                 }
               ])
               |> Enum.sort_by(&{&1.route_id, &1.stop_id, &1.direction_id, &1.trip_id})
    end
  end
end
