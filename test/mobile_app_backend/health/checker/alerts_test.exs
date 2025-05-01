defmodule MobileAppBackend.Health.Checker.AlertsTest do
  @moduledoc false
  use ExUnit.Case

  alias MobileAppBackend.Health.Checker.Alerts, as: Checker

  import ExUnit.CaptureLog
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers

  describe "check_health/0" do
    setup do
      start_link_supervised!(Checker.LastFreshStore)
      verify_on_exit!()

      reassign_env(:mobile_app_backend, MBTAV3API.Store.Alerts, AlertsStoreMock)

      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/alerts"}, options: _params} ->
          {:ok,
           Req.Response.json(%{
             data: [
               %{
                 attributes: %{
                   active_period: [
                     %{
                       end: nil,
                       start: "2025-02-05T14:49:00-05:00"
                     }
                   ],
                   banner: nil,
                   cause: "UNKNOWN_CAUSE",
                   created_at: "2025-02-05T14:49:33-05:00",
                   description:
                     "Scheduled to complete sometime in 2027, the Reconstruction of Foster Street includes widening and resurfacing with the addition of bicycle lanes.  ",
                   duration_certainty: "UNKNOWN",
                   effect: "STATION_ISSUE",
                   header:
                     "Littleton/Route 495 passengers can expect occasional traffic and detours accessing the station due to the Foster Street reconstruction work. ",
                   image: nil,
                   image_alternative_text: nil,
                   informed_entity: [
                     %{
                       stop: "FR-0301-01",
                       route_type: 2,
                       route: "CR-Fitchburg",
                       activities: [
                         "BOARD"
                       ]
                     },
                     %{
                       stop: "FR-0301-02",
                       route_type: 2,
                       route: "CR-Fitchburg",
                       activities: [
                         "BOARD"
                       ]
                     },
                     %{
                       stop: "place-FR-0301",
                       route_type: 2,
                       route: "CR-Fitchburg",
                       activities: [
                         "BOARD"
                       ]
                     }
                   ],
                   lifecycle: "ONGOING",
                   service_effect: "Change at Littleton/Route 495",
                   severity: 1,
                   short_header:
                     "Littleton/Route 495 passengers can expect occasional traffic and detours accessing the station due to the Foster Street reconstruction work",
                   timeframe: "Ongoing",
                   updated_at: "2025-02-12T14:49:16-05:00",
                   url: nil
                 },
                 id: "625935",
                 links: %{
                   self: "/alerts/625935"
                 },
                 type: "alert"
               }
             ]
           })}
        end
      )

      :ok
    end

    test "returns ok when alert counts match" do
      expect(AlertsStoreMock, :fetch, fn _ ->
        [build(:alert, id: "a_1", effect: :shuttle)]
      end)

      assert :ok = Checker.check_health()
    end

    test "returns ok when alert counts do not match but last match time < 5 min" do
      expect(AlertsStoreMock, :fetch, fn _ ->
        [build(:alert, id: "a_1", effect: :shuttle), build(:alert, id: "a_2", effect: :closure)]
      end)

      set_log_level(:warning)

      Checker.LastFreshStore.update_last_fresh_timestamp(DateTime.utc_now())

      assert :ok = Checker.check_health()
    end

    test "returns error when alert counts do not match and last match time > 5 min" do
      expect(AlertsStoreMock, :fetch, fn _ ->
        [build(:alert, id: "a_1", effect: :shuttle), build(:alert, id: "a_2", effect: :closure)]
      end)

      set_log_level(:warning)

      Checker.LastFreshStore.update_last_fresh_timestamp(~U[2024-01-01 00:00:00Z])

      msg =
        capture_log(fn ->
          assert {:error,
                  "stored_alert_count=2 backend_alert_count=1 last_fresh_timestamp=2024-01-01 00:00:00Z"} =
                   Checker.check_health()
        end)

      assert msg =~
               "Health check failed for Elixir.MobileAppBackend.Health.Checker.Alerts: stored_alert_count=2 backend_alert_count=1 last_fresh_timestamp=2024-01-01 00:00:00Z"
    end
  end

  describe "check_health/0 when alerts fetch fails" do
    setup do
      start_link_supervised!(Checker.LastFreshStore)
      verify_on_exit!()

      reassign_env(:mobile_app_backend, MBTAV3API.Store.Alerts, AlertsStoreMock)

      expect(AlertsStoreMock, :fetch, fn _ ->
        [build(:alert, id: "a_1", effect: :shuttle), build(:alert, id: "a_2", effect: :closure)]
      end)

      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/alerts"}, options: _params} ->
          {:error, :this_failed}
        end
      )

      :ok
    end

    test "returns ok when last match time < 5 min" do
      set_log_level(:warning)

      Checker.LastFreshStore.update_last_fresh_timestamp(DateTime.utc_now())

      capture_log(fn ->
        assert :ok = Checker.check_health()
      end)
    end

    test "returns error when  last match time > 5 min" do
      set_log_level(:warning)

      Checker.LastFreshStore.update_last_fresh_timestamp(~U[2024-01-01 00:00:00Z])

      msg =
        capture_log(fn ->
          assert {:error,
                  "stored_alert_count=2 backend_alert_count=unable_to_fetch last_fresh_timestamp=2024-01-01 00:00:00Z"} =
                   Checker.check_health()
        end)

      assert msg =~
               "Health check failed for Elixir.MobileAppBackend.Health.Checker.Alerts: stored_alert_count=2 backend_alert_count=unable_to_fetch last_fresh_timestamp=2024-01-01 00:00:00Z"
    end
  end
end
