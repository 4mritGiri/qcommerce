# priv/repo/migrations/20260101000004_create_users.exs
defmodule Qcommerce.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def up do
    # Create the role enum type first
    execute "CREATE TYPE user_role AS ENUM ('customer', 'picker', 'rider', 'branch_manager', 'super_admin')"

    create table(:users, primary_key: false) do
      add :id,            :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :email,         :string,    null: false
      add :phone,         :string,    null: false
      add :full_name,     :string,    null: false
      add :password_hash, :string,    null: false
      add :role,          :user_role, null: false, default: "customer"
      add :is_active,     :boolean,   null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:phone])
    create index(:users, [:role])
  end

  def down do
    drop table(:users)
    execute "DROP TYPE IF EXISTS user_role"
  end
end
