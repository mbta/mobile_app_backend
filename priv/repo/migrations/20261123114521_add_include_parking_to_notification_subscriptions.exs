defmodule MobileAppBackend.Repo.Migrations.AddIncludeParkingToNotificationSubscriptions do
  use Ecto.Migration

  def change do
    alter table(:notification_subscriptions) do
      add :include_parking, :boolean, null: false, default: false
    end
  end
end
