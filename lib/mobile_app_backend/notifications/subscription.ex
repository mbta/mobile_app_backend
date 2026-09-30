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

  defmodule Key do
    alias MobileAppBackend.Notifications.Subscription

    @type t :: %__MODULE__{
            route_id: String.t(),
            stop_id: String.t(),
            direction_id: integer(),
            include_accessibility: boolean()
          }

    @spec from_subscription(Subscription.t()) :: t()
    def from_subscription(subscription) do
      %__MODULE__{
        route_id: subscription.route_id,
        stop_id: subscription.stop_id,
        direction_id: subscription.direction_id,
        include_accessibility: subscription.include_accessibility
      }
    end
  end
end
