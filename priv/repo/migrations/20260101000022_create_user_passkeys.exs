# priv/repo/migrations/20260101000022_create_user_passkeys.exs
defmodule Qcommerce.Repo.Migrations.CreateUserPasskeys do
  use Ecto.Migration

  def change do
    create table(:user_passkeys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :external_id, :binary, null: false
      add :public_key, :binary, null: false
      add :nickname, :string, default: "My Passkey"

      timestamps()
    end

    create index(:user_passkeys, [:user_id])
    create unique_index(:user_passkeys, [:external_id])
  end
end
