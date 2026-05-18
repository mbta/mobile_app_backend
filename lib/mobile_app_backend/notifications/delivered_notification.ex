defmodule MobileAppBackend.Notifications.DeliveredNotification do
  use MobileAppBackend.Schema
  import Ecto.Query
  alias MBTAV3API.Alert
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User

  @type provisional_type :: :reminder | {:notification_or_update, DateTime.t()} | :all_clear
  @type final_type :: :reminder | {:notification | :update, DateTime.t()} | :all_clear

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

  @spec finalize_type(User.id(), Alert.id(), provisional_type()) :: final_type()
  def finalize_type(user_id, alert_id, type)

  def finalize_type(user_id, alert_id, {:notification_or_update, upstream_timestamp}) do
    already_notified? =
      Repo.aggregate(
        from(dn in __MODULE__,
          where:
            dn.user_id == ^user_id and dn.alert_id == ^alert_id and
              dn.type in [:notification, :update]
        ),
        :count
      ) > 0

    type_itself = if already_notified?, do: :update, else: :notification
    {type_itself, upstream_timestamp}
  end

  def finalize_type(_user_id, _alert_id, type), do: type

  @spec can_send?(User.id(), Alert.id(), provisional_type()) :: boolean()
  def can_send?(user_id, alert_id, type)

  def can_send?(user_id, alert_id, :reminder) do
    Repo.aggregate(
      from(dn in __MODULE__, where: dn.user_id == ^user_id and dn.alert_id == ^alert_id),
      :count
    ) == 0
  end

  def can_send?(user_id, alert_id, {:notification_or_update, upstream_timestamp}) do
    Repo.aggregate(
      from(dn in __MODULE__,
        where:
          dn.user_id == ^user_id and dn.alert_id == ^alert_id and
            dn.upstream_timestamp == ^upstream_timestamp and dn.type in [:notification, :update]
      ),
      :count
    ) == 0
  end

  def can_send?(user_id, alert_id, :all_clear) do
    Repo.aggregate(
      from(dn in __MODULE__,
        where:
          dn.user_id == ^user_id and dn.alert_id == ^alert_id and
            dn.type in [:reminder, :notification, :update]
      ),
      :count
    ) > 0 and
      Repo.aggregate(
        from(dn in __MODULE__,
          where: dn.user_id == ^user_id and dn.alert_id == ^alert_id and dn.type == :all_clear
        ),
        :count
      ) == 0
  end
end
