defmodule MobileAppBackend.Notifications.DeliveredNotification do
  use MobileAppBackend.Schema
  import Ecto.Query
  alias MBTAV3API.Alert
  alias MobileAppBackend.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  typed_schema "delivered_notifications" do
    belongs_to(:user, MobileAppBackend.User, null: false)
    field(:alert_id, :string, null: false) :: Alert.id()
    field(:upstream_timestamp, :utc_datetime, null: false)

    timestamps(type: :utc_datetime)
  end

  def already_sent?(user_id, alert_id, upstream_timestamp) do
    Repo.aggregate(
      from(dn in __MODULE__,
        where:
          dn.user_id == ^user_id and dn.alert_id == ^alert_id and
            dn.upstream_timestamp == ^upstream_timestamp
      ),
      :count
    ) == 1
  end
end
