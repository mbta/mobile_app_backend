defmodule MobileAppBackend.Notifications.Engine.OutgoingNotificationTest do
  use ExUnit.Case, async: true

  import MobileAppBackend.Factory

  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Alerts.AlertSummary.Timeframe
  alias MobileAppBackend.Notifications.Engine.OutgoingNotification
  alias MobileAppBackend.Notifications.NotificationTitle

  describe "localize/2" do
    setup do
      alert = build(:alert, id: "alert-id", effect: :suspension)

      summary = %AlertSummary.Standard{
        effect: :suspension,
        location: nil,
        timeframe: %Timeframe.UntilFurtherNotice{},
        recurrence: nil
      }

      title = %NotificationTitle.ModeLabel{label: "66", mode: :bus}

      %{alert: alert, summary: summary, title: title}
    end

    test "standard initial notification", %{
      alert: alert,
      summary: summary,
      title: title
    } do
      outgoing_notification = %OutgoingNotification{
        title: title,
        summary: summary,
        subscriptions: [],
        alert: alert,
        type: {:notification, ~U[2026-08-26 12:00:00Z]}
      }

      assert %OutgoingNotification.Localized{
               title: "66 bus",
               body: "Service suspended until further notice",
               subscriptions: [],
               alert_id: "alert-id",
               alert_effect: :suspension,
               type: {:notification, ~U[2026-08-26 12:00:00Z]},
               locale: "en"
             } = OutgoingNotification.localize(outgoing_notification, "en")
    end

    test "update prefix", %{alert: alert, summary: summary, title: title} do
      outgoing_notification = %OutgoingNotification{
        title: title,
        summary: summary,
        subscriptions: [],
        alert: alert,
        type: {:update, ~U[2026-08-26 12:00:00Z]}
      }

      assert %OutgoingNotification.Localized{
               body: "Update: Service suspended until further notice",
               type: {:update, ~U[2026-08-26 12:00:00Z]}
             } = OutgoingNotification.localize(outgoing_notification, "en")
    end

    defp delay_notification(title, location) do
      %OutgoingNotification{
        title: title,
        summary: %AlertSummary.Standard{
          effect: :delay,
          location: location,
          timeframe: nil,
          recurrence: nil
        },
        subscriptions: [],
        alert: build(:alert, id: "alert-id", effect: :delay, severity: 5, cause: :unknown_cause),
        type: {:notification, ~U[2026-08-26 12:00:00Z]}
      }
    end

    test "delay omits whole route location matching the title" do
      notification =
        delay_notification(
          %NotificationTitle.BareLabel{label: "Red Line"},
          %AlertSummary.Location.WholeRoute{route_label: "Red Line", route_type: :heavy_rail}
        )

      assert %{title: "Red Line", body: "Delays of about 20 minutes"} =
               OutgoingNotification.localize(notification, "en")
    end

    test "delay omits whole route bus location matching the title" do
      notification =
        delay_notification(
          %NotificationTitle.ModeLabel{label: "66", mode: :bus},
          %AlertSummary.Location.WholeRoute{route_label: "66", route_type: :bus}
        )

      assert %{title: "66 bus", body: "Delays of about 20 minutes"} =
               OutgoingNotification.localize(notification, "en")
    end

    test "delay keeps Green Line branch location under a Green Line title" do
      notification =
        delay_notification(
          %NotificationTitle.BareLabel{label: "Green Line"},
          %AlertSummary.Location.WholeRoute{route_label: "Green Line C", route_type: :light_rail}
        )

      assert %{title: "Green Line", body: "Delays of about 20 minutes on Green Line C"} =
               OutgoingNotification.localize(notification, "en")
    end

    test "non-delay keeps whole route location matching the title" do
      notification =
        delay_notification(
          %NotificationTitle.BareLabel{label: "Red Line"},
          %AlertSummary.Location.WholeRoute{route_label: "Red Line", route_type: :heavy_rail}
        )

      notification = %OutgoingNotification{
        notification
        | alert: build(:alert, id: "alert-id", effect: :suspension),
          summary: %AlertSummary.Standard{
            notification.summary
            | effect: :suspension,
              timeframe: %Timeframe.UntilFurtherNotice{}
          }
      }

      assert %{body: "Service suspended on Red Line until further notice"} =
               OutgoingNotification.localize(notification, "en")
    end
  end
end
