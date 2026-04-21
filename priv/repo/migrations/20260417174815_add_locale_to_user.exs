defmodule MobileAppBackend.Repo.Migrations.AddLocaleToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :locale, :string, null: true
    end
  end
end
