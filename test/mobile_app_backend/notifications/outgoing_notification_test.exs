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
  end
end
