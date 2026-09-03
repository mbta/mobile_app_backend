defmodule MobileAppBackend.Repo.Migrations.AddAppVersionAndPlatformToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :app_version, :string, null: true
      add :platform, :string, null: true
    end
  end
end
