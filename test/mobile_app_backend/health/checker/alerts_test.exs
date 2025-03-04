defmodule MobileAppBackend.Health.Checker.AlertsTest do
  @moduledoc false
  use ExUnit.Case

  alias MobileAppBackend.Health.Checker.Alerts, as: Checker

  import ExUnit.CaptureLog
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers

  describe "healthy?/0" do
    setup do
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

    test "returns true when alert counts match" do
      expect(AlertsStoreMock, :fetch, fn _ ->
        [build(:alert, id: "a_1", effect: :shuttle)]
      end)

      assert Checker.healthy?()
    end

    test "returns false when alert counts do not match" do
      expect(AlertsStoreMock, :fetch, fn _ ->
        [build(:alert, id: "a_1", effect: :shuttle), build(:alert, id: "a_2", effect: :closure)]
      end)

      set_log_level(:warning)

      msg =
        capture_log(fn ->
          refute Checker.healthy?()
        end)

      assert msg =~
               "Health check failed for Elixir.MobileAppBackend.Health.Checker.Alerts: stored alert count 2 != backend alert count 1"
    end
  end
end
