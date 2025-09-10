defmodule MobileAppBackend.Repo.Migrations.CreateNotificationSubscriptions do
  use Ecto.Migration

  def change do
    create table(:notification_subscriptions) do
      add :user_id, references(:users)
      add :route_id, :string, null: false
      add :stop_id, :string, null: false
      add :direction_id, :int, null: false
      add :include_accessibility, :boolean, null: false
    end

    create unique_index(:notification_subscriptions, [:user_id, :route_id, :stop_id, :direction_id], name: :user_rsd_unique_index )

    create index(:notification_subscriptions, [:route_id], name: :route_id_index)

    create index(:notification_subscriptions, [:stop_id], name: :stop_id_index)
  end
end
