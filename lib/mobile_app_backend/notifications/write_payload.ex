defmodule MobileAppBackend.Notifications.WritePayload do
  alias Ecto.Changeset
  alias MobileAppBackend.Notifications
  alias MobileAppBackend.User

  defmodule Window do
    @type t :: %__MODULE__{
            start_time: Time.t(),
            end_time: Time.t(),
            days_of_week: [Calendar.ISO.day_of_week()]
          }
    defstruct [:start_time, :end_time, :days_of_week]

    def parse!(%{
          "start_time" => start_time,
          "end_time" => end_time,
          "days_of_week" => days_of_week
        }) do
      %__MODULE__{
        start_time: parse_time!(start_time),
        end_time: parse_time!(end_time),
        days_of_week: Enum.sort(days_of_week)
      }
    end

    defp parse_time!(time) do
      case String.length(time) do
        8 -> Time.from_iso8601!(time)
        5 -> Time.from_iso8601!(time <> ":00")
      end
    end

    @spec changeset(Notifications.Window.t(), t()) :: Changeset.t(Notifications.Window.t())
    def changeset(%Notifications.Window{} = current, %__MODULE__{} = desired) do
      Changeset.change(current, Map.from_struct(desired))
    end
  end

  defmodule Subscription do
    @type t :: %__MODULE__{
            route_id: String.t(),
            stop_id: String.t(),
            direction_id: 0 | 1,
            include_accessibility: boolean(),
            windows: MapSet.t(Window.t())
          }
    defstruct [:route_id, :stop_id, :direction_id, :include_accessibility, :windows]

    def parse!(%{
          "route_id" => route_id,
          "stop_id" => stop_id,
          "direction_id" => direction_id,
          "include_accessibility" => include_accessibility,
          "windows" => windows
        }) do
      %__MODULE__{
        route_id: route_id,
        stop_id: stop_id,
        direction_id: direction_id,
        include_accessibility: include_accessibility,
        windows: MapSet.new(windows, &Window.parse!/1)
      }
    end

    @spec changeset(Changeset.t(Notifications.Subscription.t()), t()) ::
            Changeset.t(Notifications.Subscription.t())
    def changeset(current, %__MODULE__{} = desired) do
      # since windows don’t really have identities,
      # we just turn the first window from the DB into the first window from the payload, etc
      current_windows =
        Changeset.get_assoc(current, :windows, :struct)
        |> Enum.with_index(fn window, index -> {index, window} end)
        |> Map.new()

      windows =
        Enum.with_index(
          desired.windows,
          &Window.changeset(Map.get(current_windows, &2, %Notifications.Window{}), &1)
        )

      Changeset.change(current,
        route_id: desired.route_id,
        stop_id: desired.stop_id,
        direction_id: desired.direction_id,
        include_accessibility: desired.include_accessibility
      )
      |> Changeset.put_assoc(:windows, windows)
    end

    @spec key(Changeset.t(Notifications.Subscription.t()) | t()) ::
            {route_id :: String.t(), stop_id :: String.t(), direction_id :: 0 | 1}
    def key(%__MODULE__{route_id: route_id, stop_id: stop_id, direction_id: direction_id}) do
      {route_id, stop_id, direction_id}
    end

    def key(%Changeset{} = subscription) do
      {Changeset.get_field(subscription, :route_id), Changeset.get_field(subscription, :stop_id),
       Changeset.get_field(subscription, :direction_id)}
    end
  end

  @type t :: %__MODULE__{fcm_token: String.t(), subscriptions: MapSet.t(Subscription.t())}
  defstruct [:fcm_token, :subscriptions]

  def parse(payload) do
    {:ok, parse!(payload)}
  rescue
    _ -> :error
  end

  def parse!(%{"fcm_token" => fcm_token, "subscriptions" => subscriptions}) do
    %__MODULE__{
      fcm_token: fcm_token,
      subscriptions: MapSet.new(subscriptions, &Subscription.parse!/1)
    }
  end

  @spec changeset(Changeset.t(User.t()), desired :: t()) :: Changeset.t(User.t())
  def changeset(changeset, %__MODULE__{} = desired) do
    current_subscriptions_by_key =
      changeset
      |> Changeset.get_assoc(:notification_subscriptions, :changeset)
      |> Map.new(&{Subscription.key(&1), &1})

    subscriptions =
      Enum.map(desired.subscriptions, fn desired ->
        key = Subscription.key(desired)

        current =
          Map.get(
            current_subscriptions_by_key,
            key,
            Changeset.change(%Notifications.Subscription{})
          )

        Subscription.changeset(current, desired)
      end)

    # put_assoc will automatically delete anything that wasn’t included
    Changeset.put_assoc(changeset, :notification_subscriptions, subscriptions)
  end
end
