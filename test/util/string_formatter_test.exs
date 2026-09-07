defmodule Util.StringFormatterTest do
  use ExUnit.Case
  alias MobileAppBackend.Alerts.AlertSummary.Location
  alias Util.StringFormatter

  describe "format_list_for_log/2" do
    test "formats a list with more items than max_items" do
      list = [1, 2, 3, 4, 5]
      assert StringFormatter.format_list_for_log(list, 3) == "[1, 2, 3]..."
    end

    test "formats a list with fewer items than max_items" do
      list = [1, 2]
      assert StringFormatter.format_list_for_log(list, 3) == "[1, 2]"
    end

    test "formats list of struct" do
      list = [
        %Location.WholeRoute{route_label: "route_1", route_type: "type_1"},
        %Location.AffectedStops{stops: ["stop_1", "stop_2"]}
      ]

      assert StringFormatter.format_list_for_log(list, 1) ==
               "[%MobileAppBackend.Alerts.AlertSummary.Location.WholeRoute{route_label: \"route_1\", route_type: \"type_1\"}]..."
    end
  end
end
