defmodule MobileAppBackend.Notifications.Engine.OutgoingNotification do
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MBTAV3API.Alert
  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Alerts.FormattedAlert
  alias MobileAppBackend.Notifications.NotificationTitle

  @type t :: %__MODULE__{
          title: NotificationTitle.t(),
          summary: AlertSummary.t(),
          subscriptions: [Subscription.t()],
          alert: Alert.t(),
          type: DeliveredNotification.type()
        }
  defstruct [:title, :summary, :subscriptions, :alert, :type]

  defmodule Localized do
    @type t :: %__MODULE__{
            title: String.t(),
            body: String.t(),
            subscriptions: [Subscription.t()],
            alert_id: Alert.id(),
            type: DeliveredNotification.type(),
            locale: Gettext.locale()
          }
    defstruct [:title, :body, :subscriptions, :alert_id, :type, :locale]
  end

  @spec localize(__MODULE__.t(), Gettext.locale()) :: Localized.t()
  @doc """
  Stringify the notification's title & body in the given locale
  """
  def localize(outgoing_notification, locale) do
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
      type: outgoing_notification.type,
      locale: locale
    }
  end
end
