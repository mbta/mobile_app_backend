defmodule MobileAppBackend.Notifications.NotificationTitleTest do
  use ExUnit.Case, async: true

  import MobileAppBackend.Factory

  alias MobileAppBackend.Notifications.NotificationTitle

  describe "from_lines_or_routes/1" do
    test "Silver Line" do
      sl1 =
        build(:route,
          long_name: "Logan Airport Terminals - South Station",
          short_name: "SL1",
          line_id: "line-SLWaterfront"
        )

      sl2 =
        build(:route,
          long_name: "Design Center - South Station",
          short_name: "SL2",
          line_id: "line-SLWaterfront"
        )

      sl3 =
        build(:route,
          long_name: "Chelsea Station - South Station",
          short_name: "SL3",
          line_id: "line-SLWaterfront"
        )

      slw =
        build(:route,
          long_name: "Silver Line Way - South Station",
          short_name: "SLW",
          line_id: "line-SLWaterfront"
        )

      sl4 =
        build(:route,
          long_name: "Nubian Station - South Station",
          short_name: "SL4",
          line_id: "line-SLWashington"
        )

      sl5 =
        build(:route,
          long_name: "Nubian Station - Temple Place",
          short_name: "SL5",
          line_id: "line-SLWashington"
        )

      assert NotificationTitle.from_lines_or_routes([sl1]) == %NotificationTitle.BareLabel{
               label: "Silver Line SL1"
             }

      assert NotificationTitle.from_lines_or_routes([sl2]) == %NotificationTitle.BareLabel{
               label: "Silver Line SL2"
             }

      assert NotificationTitle.from_lines_or_routes([sl3]) == %NotificationTitle.BareLabel{
               label: "Silver Line SL3"
             }

      assert NotificationTitle.from_lines_or_routes([slw]) == %NotificationTitle.BareLabel{
               label: "Silver Line SLW"
             }

      assert NotificationTitle.from_lines_or_routes([sl4]) == %NotificationTitle.BareLabel{
               label: "Silver Line SL4"
             }

      assert NotificationTitle.from_lines_or_routes([sl5]) == %NotificationTitle.BareLabel{
               label: "Silver Line SL5"
             }
    end

    test "bus" do
      route =
        build(:route,
          type: :bus,
          long_name: "#{System.unique_integer()}",
          short_name: "#{System.unique_integer()}"
        )

      assert NotificationTitle.from_lines_or_routes([route]) == %NotificationTitle.ModeLabel{
               label: route.short_name,
               mode: :bus
             }
    end

    test "commuter rail" do
      route =
        build(:route,
          type: :commuter_rail,
          long_name: "Framingham/Worcester Line",
          short_name: "Fr/Wo"
        )

      assert NotificationTitle.from_lines_or_routes([route]) == %NotificationTitle.BareLabel{
               label: "Framingham / Worcester Line"
             }
    end

    test "no short name" do
      line = build(:line, long_name: "#{System.unique_integer()}", short_name: "")
      route = build(:route, type: :ufo, long_name: "#{System.unique_integer()}", short_name: "")

      assert NotificationTitle.from_lines_or_routes([line]) == %NotificationTitle.BareLabel{
               label: line.long_name
             }

      assert NotificationTitle.from_lines_or_routes([route]) == %NotificationTitle.BareLabel{
               label: route.long_name
             }
    end

    test "no long name" do
      line = build(:line, long_name: "", short_name: "#{System.unique_integer()}")
      route = build(:route, type: :ufo, long_name: "", short_name: "#{System.unique_integer()}")

      assert NotificationTitle.from_lines_or_routes([line]) == %NotificationTitle.BareLabel{
               label: line.short_name
             }

      assert NotificationTitle.from_lines_or_routes([route]) == %NotificationTitle.BareLabel{
               label: route.short_name
             }
    end

    test "prefers long name" do
      line =
        build(:line,
          long_name: "#{System.unique_integer()}",
          short_name: "#{System.unique_integer()}"
        )

      route =
        build(:route,
          type: :ufo,
          long_name: "#{System.unique_integer()}",
          short_name: "#{System.unique_integer()}"
        )

      assert NotificationTitle.from_lines_or_routes([line]) == %NotificationTitle.BareLabel{
               label: line.long_name
             }

      assert NotificationTitle.from_lines_or_routes([route]) == %NotificationTitle.BareLabel{
               label: route.long_name
             }
    end

    test "multiple routes" do
      routes = build_list(2, :route)
      assert NotificationTitle.from_lines_or_routes(routes) == %NotificationTitle.MultipleRoutes{}
    end
  end
end
