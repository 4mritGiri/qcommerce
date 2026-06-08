defmodule Qcommerce.Repo.Migrations.CreateCartShares do
  use Ecto.Migration

  def change do
    create table(:cart_shares, primary_key: false) do
      add :id,         :binary_id, primary_key: true
      add :token,      :string,    null: false, size: 16
      add :items,      :map,       null: false
      add :total,      :decimal,   precision: 10, scale: 2, null: false
      add :item_count, :integer,   null: false
      add :view_count, :integer,   default: 0, null: false
      add :creator_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :expires_at, :utc_datetime, null: false

      timestamps()
    end

    create unique_index(:cart_shares, [:token])
    create index(:cart_shares, [:expires_at])    # for prune queries
    create index(:cart_shares, [:creator_id])
  end
end
