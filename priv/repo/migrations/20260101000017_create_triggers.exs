# priv/repo/migrations/20260101000017_create_triggers.exs
defmodule Qcommerce.Repo.Migrations.CreateTriggers do
  use Ecto.Migration

  def up do
    # -------------------------------------------------------------------------
    # TRIGGER 1: Double-entry balance enforcement
    # Fires AFTER COMMIT (DEFERRED) — verifies SUM(debits) = SUM(credits)
    # for every journal. MUST be DEFERRED so all lines are inserted before
    # the check fires. An IMMEDIATE trigger would fail after the first line.
    # -------------------------------------------------------------------------
    execute """
      CREATE OR REPLACE FUNCTION enforce_double_entry_balance()
      RETURNS TRIGGER LANGUAGE plpgsql AS $$
      DECLARE
        v_debits  NUMERIC(15,4);
        v_credits NUMERIC(15,4);
      BEGIN
        SELECT
          COALESCE(SUM(amount) FILTER (WHERE entry_type = 'debit'),  0),
          COALESCE(SUM(amount) FILTER (WHERE entry_type = 'credit'), 0)
        INTO v_debits, v_credits
        FROM journal_lines
        WHERE journal_id = NEW.journal_id
          AND branch_id  = NEW.branch_id;

        IF v_debits <> v_credits THEN
          RAISE EXCEPTION
            'Double-entry violation: journal_id=% debits=% credits=%',
            NEW.journal_id, v_debits, v_credits;
        END IF;
        RETURN NULL;
      END;
      $$
    """

    execute """
      CREATE CONSTRAINT TRIGGER journal_lines_double_entry_check
        AFTER INSERT OR UPDATE ON journal_lines
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW
        EXECUTE FUNCTION enforce_double_entry_balance()
    """

    # -------------------------------------------------------------------------
    # TRIGGER 2: Fiscal year boundary enforcement
    # Validates posted_at falls within the referenced fiscal year's date range.
    # Cannot be a CHECK constraint — CHECK cannot reference other tables.
    # IMMEDIATELY checked (single-row property, no reason to defer).
    # -------------------------------------------------------------------------
    execute """
      CREATE OR REPLACE FUNCTION enforce_fiscal_year_boundary()
      RETURNS TRIGGER LANGUAGE plpgsql AS $$
      DECLARE
        v_start DATE;
        v_end   DATE;
      BEGIN
        SELECT start_date, end_date INTO v_start, v_end
        FROM   fiscal_years WHERE id = NEW.fiscal_year_id;

        IF NEW.posted_at::DATE NOT BETWEEN v_start AND v_end THEN
          RAISE EXCEPTION
            'Fiscal boundary violation: posted_at=% outside fiscal_year_id=% [% to %]',
            NEW.posted_at, NEW.fiscal_year_id, v_start, v_end;
        END IF;
        RETURN NULL;
      END;
      $$
    """

    execute """
      CREATE CONSTRAINT TRIGGER journal_lines_fiscal_boundary_check
        AFTER INSERT ON journal_lines
        DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE FUNCTION enforce_fiscal_year_boundary()
    """

    # -------------------------------------------------------------------------
    # TRIGGER 3: updated_at auto-maintenance
    # -------------------------------------------------------------------------
    execute """
      CREATE OR REPLACE FUNCTION touch_updated_at()
      RETURNS TRIGGER LANGUAGE plpgsql AS $$
      BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
      END;
      $$
    """

    for table <- ~w(branches users products orders accounts) do
      execute """
        CREATE TRIGGER #{table}_updated_at
          BEFORE UPDATE ON #{table}
          FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
      """
    end
  end

  def down do
    for table <- ~w(branches users products orders accounts) do
      execute "DROP TRIGGER IF EXISTS #{table}_updated_at ON #{table}"
    end

    execute "DROP TRIGGER IF EXISTS journal_lines_fiscal_boundary_check ON journal_lines"
    execute "DROP TRIGGER IF EXISTS journal_lines_double_entry_check    ON journal_lines"
    execute "DROP FUNCTION IF EXISTS touch_updated_at()"
    execute "DROP FUNCTION IF EXISTS enforce_fiscal_year_boundary()"
    execute "DROP FUNCTION IF EXISTS enforce_double_entry_balance()"
  end
end
