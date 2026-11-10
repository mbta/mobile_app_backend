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

    test "all clear with a single other active alert links to that alert", %{
      alert: alert,
      title: title
    } do
      outgoing_notification = %OutgoingNotification{
        title: title,
        summary: %AlertSummary.AllClear{
          effect: :suspension,
          other_active_alerts: [%AlertSummary.OtherActiveAlert{alert_id: "other", effect: :delay}]
        },
        subscriptions: [],
        alert: alert,
        type: :all_clear
      }

      assert %OutgoingNotification.Localized{
               alert_id: "alert-id",
               deep_link_alert_id: "other"
             } = OutgoingNotification.localize(outgoing_notification, "en")
    end

    test "all clear with several other active alerts has no alert link", %{
      alert: alert,
      title: title
    } do
      outgoing_notification = %OutgoingNotification{
        title: title,
        summary: %AlertSummary.AllClear{
          effect: :suspension,
          other_active_alerts: [
            %AlertSummary.OtherActiveAlert{alert_id: "other-1", effect: :delay},
            %AlertSummary.OtherActiveAlert{alert_id: "other-2", effect: :detour}
          ]
        },
        subscriptions: [],
        alert: alert,
        type: :all_clear
      }

      assert %OutgoingNotification.Localized{deep_link_alert_id: nil} =
               OutgoingNotification.localize(outgoing_notification, "en")
    end
  end
end
