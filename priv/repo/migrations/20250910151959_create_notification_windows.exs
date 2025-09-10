defmodule MobileAppBackend.Repo.Migrations.CreateNotificationWindows do
  use Ecto.Migration

  def change do
    create table(:notification_subscription_windows) do
      add :subscription_id, references(:notification_subscriptions)
      add :start_time, :time, null: false
      add :end_time, :time, null: false
      add :days_of_week, {:array, :int}, null: false
    end
  end
end
