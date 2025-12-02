defmodule MobileAppBackend.Repo.Migrations.AddDeliveredNotificationType do
  use Ecto.Migration

  def change do
    alter table(:delivered_notifications) do
      modify :upstream_timestamp, :utc_datetime, null: true, from: {:utc_datetime, null: false}
      add :type, :string, default: "notification", null: false
    end
  end
end
