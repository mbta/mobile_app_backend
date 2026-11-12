defmodule MobileAppBackend.Notifications.Engine.OutgoingNotification do
  use MobileAppBackend.Gettext

  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Alerts.AlertSummary.Location
  alias MobileAppBackend.Alerts.FormattedAlert
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.NotificationTitle

  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.PresentationStrings

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
    title = NotificationTitle.to_string(outgoing_notification.title, locale)

    body =
      FormattedAlert.summary(
        %FormattedAlert{
          alert: outgoing_notification.alert,
          alert_summary:
            outgoing_notification.alert
            |> omit_location_repeating_title(outgoing_notification.summary, title, locale)
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
      title: title,
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

  # A delay on the whole route that's already named by the title doesn't need to repeat it in the body.
  # Comparing the localized strings means a "Green Line" title still keeps a "Green Line C" location.
  @spec omit_location_repeating_title(Alert.t(), AlertSummary.t(), String.t(), Gettext.locale()) ::
          AlertSummary.t()
  defp omit_location_repeating_title(
         %Alert{effect: :delay},
         %AlertSummary.Standard{location: %Location.WholeRoute{} = location} = summary,
         title,
         locale
       ) do
    location_label =
      Gettext.with_locale(locale, fn ->
        PresentationStrings.mode_label(location.route_label, location.route_type)
      end)

    if location_label == title do
      %AlertSummary.Standard{summary | location: %Location.Omit{reason: :matches_title}}
    else
      summary
    end
  end

  defp omit_location_repeating_title(_alert, summary, _title, _locale), do: summary
end
