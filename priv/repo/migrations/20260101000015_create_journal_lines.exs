# priv/repo/migrations/20260101000015_create_journal_lines.exs
defmodule Qcommerce.Repo.Migrations.CreateJournalLines do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE entry_type AS ENUM ('debit', 'credit')"

    # Create the partitioned parent table.
    # Partitioned by branch_id (LIST) — Level 1 isolation.
    # Each branch gets its own partition, so branch queries never
    # touch other branches' pages.
    execute """
      CREATE TABLE journal_lines (
        id              UUID          NOT NULL DEFAULT uuid_generate_v4(),
        journal_id      UUID          NOT NULL,
        branch_id       UUID          NOT NULL,
        fiscal_year_id  UUID          NOT NULL,
        account_id      UUID          NOT NULL REFERENCES accounts(id),
        amount          NUMERIC(15,4) NOT NULL,
        entry_type      entry_type    NOT NULL,
        shard_id        SMALLINT      NOT NULL DEFAULT 0,
        idempotency_key UUID          NOT NULL,
        posted_at       TIMESTAMPTZ   NOT NULL,
        inserted_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
        PRIMARY KEY (id, branch_id, fiscal_year_id),
        CONSTRAINT journal_lines_amount_positive CHECK (amount > 0),
        CONSTRAINT journal_lines_shard_valid     CHECK (shard_id >= 0 AND shard_id < 16)
      ) PARTITION BY LIST (branch_id)
    """

    # THE CRITICAL COMPOSITE INDEX
    # Drives the hot delta-balance query:
    #   WHERE branch_id = X AND account_id = Y AND fiscal_year_id = Z
    #   AND inserted_at > checkpointed_through
    # INCLUDE pushes amount + entry_type into index leaf pages
    # enabling true index-only scans without heap fetches.
    # Propagates automatically to all child partitions (PostgreSQL 11+).
    execute """
      CREATE INDEX journal_lines_balance_scan_idx
      ON journal_lines (branch_id, account_id, shard_id, inserted_at DESC)
      INCLUDE (amount, entry_type)
    """

    execute """
      CREATE INDEX journal_lines_journal_id_idx
      ON journal_lines (journal_id, branch_id, fiscal_year_id)
    """

    execute """
      CREATE UNIQUE INDEX journal_lines_idempotency_key_idx
      ON journal_lines (idempotency_key, branch_id, fiscal_year_id)
    """
  end

  def down do
    execute "DROP TABLE IF EXISTS journal_lines"
    execute "DROP TYPE IF EXISTS entry_type"
  end
end
