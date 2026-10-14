defmodule MobileAppBackend.Notifications.DeliveredNotification do
  use MobileAppBackend.Schema
  import Ecto.Query
  alias MBTAV3API.Alert
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User

  @type type :: :reminder | {:notification | :update, DateTime.t()} | :all_clear

  @primary_key {:id, :binary_id, autogenerate: true}
  typed_schema "delivered_notifications" do
    belongs_to(:user, MobileAppBackend.User, null: false)
    field(:alert_id, :string, null: false) :: Alert.id()
    field(:upstream_timestamp, :utc_datetime, null: true)

    field(:type, Ecto.Enum,
      default: :notification,
      values: [:notification, :update, :reminder, :all_clear],
      null: false
    )

    timestamps(type: :utc_datetime)
  end

  @doc """
  Get the last delivered notification for each user who was delivered any of the given alerts
  """
  @spec latest_delivered_per_user([Alert.id()]) :: %{User.id() => %{Alert.id() => t()}}
  def latest_delivered_per_user(alert_ids) do
    from(dn in __MODULE__,
      where: dn.alert_id in ^alert_ids,
      order_by: [desc: dn.inserted_at]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.user_id)
    |> Map.new(fn {user_id, delivered_notifications} ->
      {user_id,
       delivered_notifications
       |> Enum.group_by(& &1.alert_id)
       # Ordered by inserted_at descending, so List.first gives the latest
       |> Map.new(fn {alert_id, dns} -> {alert_id, List.first(dns)} end)}
    end)
  end

  @spec can_send?(Alert.t(), t() | nil, type()) :: boolean()
  def can_send?(alert, last_delivered, type)

  def can_send?(_alert, last_delivered, :reminder) do
    last_delivered == nil
  end

  def can_send?(_alert, last_delivered, {:notification, _upstream_timestamp}) do
    last_delivered == nil || last_delivered.type != :notification
  end

  def can_send?(_alert, nil, {:update, _upstream_timestamp}) do
    # No update unless there has already been an earlier delivered notification
    false
  end

  def can_send?(_alert, last_delivered, {:update, upstream_timestamp}) do
    # Have they already been sent a notification or update for this alert with the same upstream timestamp
    type_matches = last_delivered.type in [:notification, :update]

    different_timestamp =
      case last_delivered.upstream_timestamp do
        nil -> !is_nil(upstream_timestamp)
        last_delivered_ts -> DateTime.diff(upstream_timestamp, last_delivered_ts, :second) > 0
      end

    type_matches && different_timestamp
  end

  def can_send?(_alert, last_delivered, :all_clear) do
    last_delivered != nil && last_delivered.type != :all_clear
  end

  @doc """
  Returns the priority of a given notification type. Higher numbers indicate higher priority.
  If a user could be notified with multiple types for the same alert, the type with the highest
  priority should be sent.
  """
  @spec type_priority(type() | nil) :: non_neg_integer()
  def type_priority(:all_clear), do: 4
  def type_priority({:notification, _}), do: 3
  def type_priority({:update, _}), do: 2
  def type_priority(:reminder), do: 1
  def type_priority(_), do: 0
end
