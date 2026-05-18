defmodule MobileAppBackend.Notifications.Engine.OutgoingNotification do
  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Alerts.FormattedAlert
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.NotificationTitle

  alias MobileAppBackend.Notifications.Subscription

  @type t :: %__MODULE__{
          title: NotificationTitle.t(),
          summary: AlertSummary.t(),
          subscriptions: [Subscription.t()],
          alert: Alert.t(),
          type: DeliveredNotification.provisional_type()
        }
  defstruct [:title, :summary, :subscriptions, :alert, :type]

  defmodule Localized do
    @type t :: %__MODULE__{
            title: String.t(),
            body: String.t(),
            subscriptions: [Subscription.t()],
            alert_id: Alert.id(),
            alert_effect: Alert.effect(),
            type: DeliveredNotification.final_type(),
            locale: Gettext.locale()
          }
    defstruct [:title, :body, :subscriptions, :alert_id, :alert_effect, :type, :locale]
  end

  @spec localize(t(), Gettext.locale(), DeliveredNotification.final_type()) :: Localized.t()
  @doc """
  Stringify the notification's title & body in the given locale
  """
  def localize(outgoing_notification, locale, final_type) do
    %Localized{
      title: NotificationTitle.to_string(outgoing_notification.title, locale),
      body:
        FormattedAlert.summary(
          %FormattedAlert{
            alert: outgoing_notification.alert,
            alert_summary: outgoing_notification.summary
          },
          locale
        ),
      subscriptions: outgoing_notification.subscriptions,
      alert_id: outgoing_notification.alert.id,
      alert_effect: outgoing_notification.alert.effect,
      type: final_type,
      locale: locale
    }
  end
end
