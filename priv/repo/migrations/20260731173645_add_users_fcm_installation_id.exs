defmodule MobileAppBackend.Repo.Migrations.AddUsersFcmInstallationId do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :fcm_token, :string, null: true, from: {:string, null: false}
      add :fcm_installation_id, :string, null: true
    end

    create unique_index(:users, [:fcm_installation_id])

    create constraint(:users, :some_fcm_target,
             check: "COALESCE(fcm_installation_id, fcm_token) IS NOT NULL"
           )
  end
end
