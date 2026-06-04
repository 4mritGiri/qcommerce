# priv/repo/migrations/20260101000013_create_accounts.exs
defmodule Qcommerce.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE account_type        AS ENUM ('asset', 'liability', 'equity', 'revenue', 'expense')"
    execute "CREATE TYPE normal_balance_side  AS ENUM ('debit', 'credit')"

    create table(:accounts, primary_key: false) do
      add :id,             :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :parent_id,      references(:accounts, type: :binary_id, on_delete: :nilify_all)
      add :code,           :string,             null: false
      add :name,           :string,             null: false
      add :account_type,   :account_type,       null: false
      add :normal_balance, :normal_balance_side, null: false
      add :shard_count,    :smallint,           null: false, default: 1
      add :is_active,      :boolean,            null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:accounts, [:code])
    create index(:accounts, [:parent_id])

    # Enforce accounting law: asset/expense = debit normal, liability/equity/revenue = credit normal
    execute """
      ALTER TABLE accounts ADD CONSTRAINT accounts_normal_balance_consistent CHECK (
        (account_type IN ('asset', 'expense')               AND normal_balance = 'debit')  OR
        (account_type IN ('liability', 'equity', 'revenue') AND normal_balance = 'credit')
      )
    """

    execute """
      ALTER TABLE accounts ADD CONSTRAINT accounts_shard_count_valid
      CHECK (shard_count IN (1, 2, 4, 8, 16))
    """

    # Seed Chart of Accounts
    execute """
      INSERT INTO accounts (id, code, name, account_type, normal_balance, shard_count, inserted_at, updated_at) VALUES
        ('bbbbbbbb-0000-0000-0000-000000000001', '1000', 'Cash',                    'asset',     'debit',  16, NOW(), NOW()),
        ('bbbbbbbb-0000-0000-0000-000000000002', '1100', 'Accounts Receivable',     'asset',     'debit',   8, NOW(), NOW()),
        ('bbbbbbbb-0000-0000-0000-000000000003', '1200', 'Inventory Asset',         'asset',     'debit',   8, NOW(), NOW()),
        ('bbbbbbbb-0000-0000-0000-000000000010', '2000', 'Accounts Payable',        'liability', 'credit',  4, NOW(), NOW()),
        ('bbbbbbbb-0000-0000-0000-000000000011', '2100', 'Unearned Revenue',        'liability', 'credit', 16, NOW(), NOW()),
        ('bbbbbbbb-0000-0000-0000-000000000012', '2200', 'Tax Payable',             'liability', 'credit',  4, NOW(), NOW()),
        ('bbbbbbbb-0000-0000-0000-000000000020', '4000', 'Recognized Revenue',      'revenue',   'credit', 16, NOW(), NOW()),
        ('bbbbbbbb-0000-0000-0000-000000000021', '4100', 'Delivery Fee Revenue',    'revenue',   'credit',  8, NOW(), NOW()),
        ('bbbbbbbb-0000-0000-0000-000000000030', '5000', 'Cost of Goods Sold',      'expense',   'debit',   8, NOW(), NOW()),
        ('bbbbbbbb-0000-0000-0000-000000000031', '5100', 'Rider Payout Expense',    'expense',   'debit',   8, NOW(), NOW()),
        ('bbbbbbbb-0000-0000-0000-000000000032', '5200', 'Office Supplies Expense', 'expense',   'debit',   1, NOW(), NOW())
    """
  end

  def down do
    drop table(:accounts)
    execute "DROP TYPE IF EXISTS normal_balance_side"
    execute "DROP TYPE IF EXISTS account_type"
  end
end
