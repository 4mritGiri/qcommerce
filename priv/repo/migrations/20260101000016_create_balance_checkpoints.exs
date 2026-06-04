# priv/repo/migrations/20260101000016_create_balance_checkpoints.exs
defmodule Qcommerce.Repo.Migrations.CreateBalanceCheckpoints do
  use Ecto.Migration

  def change do
    create table(:balance_checkpoints, primary_key: false) do
      add :id,                   :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :branch_id,            references(:branches,     type: :binary_id, on_delete: :restrict), null: false
      add :account_id,           references(:accounts,     type: :binary_id, on_delete: :restrict), null: false
      add :fiscal_year_id,       references(:fiscal_years, type: :binary_id, on_delete: :restrict), null: false
      add :shard_id,             :smallint,  null: false, default: 0
      add :debit_total,          :decimal,   null: false, default: 0, precision: 15, scale: 4
      add :credit_total,         :decimal,   null: false, default: 0, precision: 15, scale: 4
      add :checkpointed_through, :utc_datetime_usec, null: false
      add :entry_count,          :integer,   null: false, default: 0

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    # Latest checkpoint lookup per shard — hot path for balance queries
    create index(:balance_checkpoints,
      [:branch_id, :account_id, :fiscal_year_id, :shard_id, :inserted_at],
      name: "balance_checkpoints_latest_idx"
    )

    create constraint(:balance_checkpoints, :shard_id_valid,
      check: "shard_id >= 0 AND shard_id < 16"
    )
  end
end
