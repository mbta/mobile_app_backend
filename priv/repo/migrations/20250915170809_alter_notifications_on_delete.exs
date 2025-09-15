defmodule MobileAppBackend.Repo.Migrations.AlterNotificationsOnDelete do
  use Ecto.Migration

  def change do
    alter table(:notification_subscriptions) do
      modify :user_id, references(:users, on_delete: :delete_all), from: references(:users)
    end

    alter table(:notification_subscription_windows) do
      modify :subscription_id, references(:notification_subscriptions, on_delete: :delete_all),
        from: references(:notification_subscriptions)
    end
  end
end
