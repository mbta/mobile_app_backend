defmodule MobileAppBackend.Notifications.WindowTest do
  alias MBTAV3API.Alert
  use MobileAppBackend.DataCase

  import Test.Support.Sigils

  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Notifications.Window
  alias MobileAppBackend.User

  test "can insert windows for subscription" do
    %{id: user_id} =
      MobileAppBackend.Repo.insert!(%User{
        fcm_token: "fake",
        fcm_last_verified: ~U[2025-09-10 00:00:00Z]
      })

    %{id: subscription_id} =
      MobileAppBackend.Repo.insert!(%Subscription{
        user_id: user_id,
        route_id: "Red",
        stop_id: "place-davis",
        direction_id: 0,
        include_accessibility: true
      })

    MobileAppBackend.Repo.insert!(%Window{
      subscription_id: subscription_id,
      start_time: ~T[08:00:00],
      end_time: ~T[09:00:00],
      days_of_week: [0, 1, 2]
    })

    MobileAppBackend.Repo.insert!(%Window{
      subscription_id: subscription_id,
      start_time: ~T[05:00:00],
      end_time: ~T[06:00:00],
      days_of_week: [3, 4, 5]
    })
  end

  describe "next_overlap/3" do
    test "nil when window ends before period starts" do
      period = %Alert.ActivePeriod{start: ~B[2026-03-20 16:11:00], end: ~B[2026-03-20 23:59:00]}

      window = %Window{
        start_time: ~T[00:00:00],
        end_time: ~T[16:10:00],
        days_of_week: Enum.to_list(1..7)
      }

      now = ~B[2026-03-20 16:12:00]
      assert Window.next_overlap(period, window, now) == nil
    end

    test "nil when window starts after period ends" do
      period = %Alert.ActivePeriod{start: ~B[2026-03-20 00:00:00], end: ~B[2026-03-20 16:14:00]}

      window = %Window{
        start_time: ~T[16:15:00],
        end_time: ~T[23:59:00],
        days_of_week: Enum.to_list(1..7)
      }

      now = ~B[2026-03-20 16:00:00]
      assert Window.next_overlap(period, window, now) == nil
    end

    test "period start when window starts before period starts" do
      period = %Alert.ActivePeriod{start: ~B[2026-03-20 16:18:00], end: nil}

      window = %Window{
        start_time: ~T[16:00:00],
        end_time: ~T[17:00:00],
        days_of_week: Enum.to_list(1..7)
      }

      now = ~B[2026-03-20 15:30:00]
      assert Window.next_overlap(period, window, now) == ~B[2026-03-20 16:18:00]
    end

    test "now when window and period already started" do
      period = %Alert.ActivePeriod{start: ~B[2026-03-20 16:00:00], end: nil}

      window = %Window{
        start_time: ~T[16:00:00],
        end_time: ~T[17:00:00],
        days_of_week: Enum.to_list(1..7)
      }

      now = ~B[2026-03-20 16:20:00]
      assert Window.next_overlap(period, window, now) == ~B[2026-03-20 16:20:00]
    end

    test "next week when today’s overlap is already over" do
      period = %Alert.ActivePeriod{start: ~B[2026-03-20 15:30:00], end: nil}

      window = %Window{
        start_time: ~T[15:00:00],
        end_time: ~T[16:00:00],
        days_of_week: [5]
      }

      now = ~B[2026-03-20 16:20:00]
      assert Window.next_overlap(period, window, now) == ~B[2026-03-27 15:00:00]
    end

    test "window start when window starts after period starts" do
      period = %Alert.ActivePeriod{start: ~B[2026-03-20 16:00:00], end: nil}

      window = %Window{
        start_time: ~T[16:21:00],
        end_time: ~T[17:00:00],
        days_of_week: Enum.to_list(1..7)
      }

      now = ~B[2026-03-20 16:10:00]
      assert Window.next_overlap(period, window, now) == ~B[2026-03-20 16:21:00]
    end

    test "checks all windows and periods" do
      p1 = %Alert.ActivePeriod{start: ~B[2026-03-20 16:23:00], end: ~B[2026-03-20 16:25:00]}
      p2 = %Alert.ActivePeriod{start: ~B[2026-03-20 16:28:00], end: ~B[2026-03-20 16:30:00]}
      w1 = %Window{start_time: ~T[16:24:00], end_time: ~T[16:26:00], days_of_week: [5]}
      w2 = %Window{start_time: ~T[16:27:00], end_time: ~T[16:29:00], days_of_week: [5]}
      now = ~B[2026-03-20 16:22:00]
      expected = ~B[2026-03-20 16:24:00]
      assert Window.next_overlap([p1, p2], [w1, w2], now) == expected
      assert Window.next_overlap([p2, p1], [w1, w2], now) == expected
      assert Window.next_overlap([p1, p2], [w2, w1], now) == expected
      assert Window.next_overlap([p2, p1], [w2, w1], now) == expected
    end
  end
end
