defmodule MBTAV3API.ServiceTest do
  use ExUnit.Case, async: true

  import MobileAppBackend.Factory

  alias MBTAV3API.Service

  describe "active_dates/1" do
    test "handles simple case" do
      service =
        build(:service,
          start_date: ~D[2025-12-05],
          end_date: ~D[2025-12-15],
          valid_days: [1, 2, 3, 4, 5, 6, 7]
        )

      assert Service.active_dates(service) == [
               ~D[2025-12-05],
               ~D[2025-12-06],
               ~D[2025-12-07],
               ~D[2025-12-08],
               ~D[2025-12-09],
               ~D[2025-12-10],
               ~D[2025-12-11],
               ~D[2025-12-12],
               ~D[2025-12-13],
               ~D[2025-12-14],
               ~D[2025-12-15]
             ]
    end

    test "filters day of week" do
      service =
        build(:service, start_date: ~D[2025-12-01], end_date: ~D[2025-12-31], valid_days: [5])

      assert Service.active_dates(service) == [
               ~D[2025-12-05],
               ~D[2025-12-12],
               ~D[2025-12-19],
               ~D[2025-12-26]
             ]
    end

    test "sorts added dates into normal dates" do
      service =
        build(:service,
          start_date: ~D[2025-12-01],
          end_date: ~D[2025-12-15],
          added_dates: [~D[2025-11-04], ~D[2025-12-10], ~D[2025-12-25]],
          valid_days: [5]
        )

      assert Service.active_dates(service) == [
               ~D[2025-11-04],
               ~D[2025-12-05],
               ~D[2025-12-10],
               ~D[2025-12-12],
               ~D[2025-12-25]
             ]
    end

    test "removes removed dates" do
      service =
        build(:service,
          start_date: ~D[2025-12-05],
          end_date: ~D[2025-12-07],
          removed_dates: [~D[2025-12-06]],
          valid_days: Range.to_list(1..7)
        )

      assert Service.active_dates(service) == [~D[2025-12-05], ~D[2025-12-07]]
    end
  end

  describe "next_active/2" do
    test "finds next active date for each service in list" do
      service1 =
        build(:service, start_date: ~D[2025-12-06], end_date: ~D[2025-12-06], valid_days: [6])

      service2 =
        build(:service,
          start_date: ~D[2025-12-01],
          end_date: ~D[2025-12-05],
          valid_days: Range.to_list(1..7)
        )

      assert Service.next_active([service1, service2], ~D[2025-12-04]) == [
               ~D[2025-12-05],
               ~D[2025-12-06]
             ]
    end

    test "skips service with no future dates" do
      service1 =
        build(:service,
          start_date: ~D[2025-12-01],
          end_date: ~D[2025-12-05],
          valid_days: Range.to_list(1..7)
        )

      service2 =
        build(:service, start_date: ~D[2025-12-03], end_date: ~D[2025-12-10], valid_days: [1])

      assert Service.next_active([service1, service2], ~D[2025-12-05]) == [~D[2025-12-08]]
    end

    test "returns empty list if no future service" do
      service = build(:service, start_date: ~D[2025-12-01], end_date: ~D[2025-12-04])
      assert Service.next_active([service], ~D[2025-12-05]) == []
    end
  end
end
