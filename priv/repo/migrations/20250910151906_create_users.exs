defmodule MobileAppBackend.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :fcm_token, :string, null: false
      add :fcm_last_verified, :utc_datetime, null: false
    end

    create unique_index(:users, [:fcm_token], name: :fcm_unique_index)
  end
end
