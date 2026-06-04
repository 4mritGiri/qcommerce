# priv/repo/migrations/20260101000003_create_fiscal_years.exs
defmodule Qcommerce.Repo.Migrations.CreateFiscalYears do
  use Ecto.Migration

  def up do
    create table(:fiscal_years, primary_key: false) do
      add :id,         :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :label,      :string,    null: false
      add :start_date, :date,      null: false
      add :end_date,   :date,      null: false
      add :is_closed,  :boolean,   null: false, default: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:fiscal_years, [:label])

    # Ensure end_date is always after start_date
    execute """
      ALTER TABLE fiscal_years
      ADD CONSTRAINT fiscal_years_dates_valid CHECK (end_date > start_date)
    """

    # Prevent overlapping fiscal years — requires btree_gist extension
    execute """
      ALTER TABLE fiscal_years
      ADD CONSTRAINT fiscal_years_no_overlap
      EXCLUDE USING GIST (daterange(start_date, end_date, '[]') WITH &&)
    """

    # Seed FY2025 and FY2026
    execute """
      INSERT INTO fiscal_years (id, label, start_date, end_date, inserted_at)
      VALUES
        ('aaaaaaaa-0000-0000-0000-000000000001', 'FY2025', '2025-01-01', '2025-12-31', NOW()),
        ('aaaaaaaa-0000-0000-0000-000000000002', 'FY2026', '2026-01-01', '2026-12-31', NOW())
    """
  end

  def down do
    drop table(:fiscal_years)
  end
end
