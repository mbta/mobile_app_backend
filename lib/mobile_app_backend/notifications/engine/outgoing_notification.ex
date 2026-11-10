defmodule MobileAppBackend.Notifications.Engine.OutgoingNotification do
  use MobileAppBackend.Gettext

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
          type: DeliveredNotification.type()
        }
  defstruct [:title, :summary, :subscriptions, :alert, :type]

  defmodule Localized do
    @type t :: %__MODULE__{
            title: String.t(),
            body: String.t(),
            subscriptions: [Subscription.t()],
            alert_id: Alert.id(),
            alert_effect: Alert.effect(),
            deep_link_alert_id: Alert.id() | nil,
            type: DeliveredNotification.type(),
            locale: Gettext.locale()
          }
    defstruct [
      :title,
      :body,
      :subscriptions,
      :alert_id,
      :alert_effect,
      :deep_link_alert_id,
      :type,
      :locale
    ]
  end

  @spec localize(t(), Gettext.locale()) :: Localized.t()
  @doc """
  Stringify the notification's title & body in the given locale
  """
  def localize(outgoing_notification, locale) do
    body =
      FormattedAlert.summary(
        %FormattedAlert{
          alert: outgoing_notification.alert,
          alert_summary: outgoing_notification.summary
        },
        locale
      )

    body =
      case outgoing_notification.type do
        {:update, _} ->
          gettext("Update: %{body}",
            comment: "Example: “Update: Service has ended”",
            body: body
          )

        _ ->
          body
      end

    %Localized{
      title: NotificationTitle.to_string(outgoing_notification.title, locale),
      body: body,
      subscriptions: outgoing_notification.subscriptions,
      alert_id: outgoing_notification.alert.id,
      alert_effect: outgoing_notification.alert.effect,
      deep_link_alert_id: single_other_active_alert_id(outgoing_notification.summary),
      type: outgoing_notification.type,
      locale: locale
    }
  end

  defp single_other_active_alert_id(%AlertSummary.AllClear{other_active_alerts: [other]}),
    do: other.alert_id

  defp single_other_active_alert_id(_summary), do: nil
end
