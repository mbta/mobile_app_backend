defmodule MobileAppBackend.Repo.Migrations.CreateDeliveredNotifications do
  use Ecto.Migration

  def change do
    create table(:delivered_notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :alert_id, :string, null: false
      add :upstream_timestamp, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:delivered_notifications, [:user_id])
    create index(:delivered_notifications, [:alert_id, :upstream_timestamp])
    create unique_index(:delivered_notifications, [:user_id, :alert_id, :upstream_timestamp])
  end
end
