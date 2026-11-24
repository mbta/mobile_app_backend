defmodule MobileAppBackend.Notifications.WritePayloadTest do
  use ExUnit.Case

  alias MobileAppBackend.Notifications.WritePayload

  describe "parse!/1" do
    test "parses valid payload with minimal fields" do
      payload = %{
        "fcm_installation_id" => "test-installation-id",
        "subscriptions" => []
      }

      result = WritePayload.parse!(payload)

      assert result.fcm_target == {:installation_id, "test-installation-id"}
      assert result.subscriptions == MapSet.new()
      assert result.locale == nil
      assert result.app_version == nil
      assert result.platform == nil
    end

    test "parses payload with single subscription" do
      payload = %{
        "fcm_installation_id" => "test-id",
        "subscriptions" => [
          %{
            "route_id" => "Red",
            "stop_id" => "place-davis",
            "direction_id" => 0,
            "include_accessibility" => true,
            "windows" => []
          }
        ]
      }

      result = WritePayload.parse!(payload)

      assert MapSet.size(result.subscriptions) == 1

      [sub] = result.subscriptions |> MapSet.to_list()
      assert sub.route_id == "Red"
      assert sub.stop_id == "place-davis"
      assert sub.direction_id == 0
      assert sub.include_accessibility == true
      assert sub.include_parking == false
      assert sub.windows == MapSet.new()
    end

    test "parses payload with subscription containing windows" do
      payload = %{
        "fcm_installation_id" => "test-id",
        "subscriptions" => [
          %{
            "route_id" => "Red",
            "stop_id" => "place-davis",
            "direction_id" => 1,
            "include_accessibility" => false,
            "include_parking" => true,
            "windows" => [
              %{
                "start_time" => "08:00",
                "end_time" => "09:30:00",
                "days_of_week" => [1, 2, 3]
              }
            ]
          }
        ]
      }

      result = WritePayload.parse!(payload)

      [sub] = result.subscriptions |> MapSet.to_list()
      assert MapSet.size(sub.windows) == 1

      [window] = sub.windows |> MapSet.to_list()
      assert window.start_time == ~T[08:00:00]
      assert window.end_time == ~T[09:30:00]
      assert window.days_of_week == [1, 2, 3]
    end
  end
end
