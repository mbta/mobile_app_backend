defmodule MobileAppBackend.Notifications.Subscription do
  use MobileAppBackend.Schema

  typed_schema "notification_subscriptions" do
    belongs_to(:user, MobileAppBackend.User)

    field(:route_id, :string, null: false)
    field(:stop_id, :string, null: false)
    field(:direction_id, :integer, null: false)
    field(:include_accessibility, :boolean, null: false)
    has_many(:windows, MobileAppBackend.Notifications.Window, on_replace: :delete_if_exists)

    timestamps(type: :utc_datetime)
  end
end
