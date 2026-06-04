# priv/repo/migrations/20260101000014_create_journals.exs
defmodule Qcommerce.Repo.Migrations.CreateJournals do
  use Ecto.Migration

  def change do
    create table(:journals, primary_key: false) do
      add :id,              :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :branch_id,       references(:branches,      type: :binary_id, on_delete: :restrict), null: false
      add :fiscal_year_id,  references(:fiscal_years,  type: :binary_id, on_delete: :restrict), null: false
      add :outbox_event_id, references(:outbox_events, type: :binary_id, on_delete: :nilify_all)
      add :idempotency_key, :binary_id,  null: false
      add :description,     :text
      add :posted_at,       :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:journals, [:idempotency_key])
    create index(:journals, [:branch_id])
    create index(:journals, [:fiscal_year_id])
    create index(:journals, [:posted_at])
  end
end
