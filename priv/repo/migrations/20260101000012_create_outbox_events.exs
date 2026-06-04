# priv/repo/migrations/20260101000012_create_outbox_events.exs
defmodule Qcommerce.Repo.Migrations.CreateOutboxEvents do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE outbox_status AS ENUM ('pending', 'processing', 'processed', 'failed')"

    create table(:outbox_events, primary_key: false) do
      add :id,              :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      # UUIDv5(order_id, event_type) — deterministic, reconstructible
      add :idempotency_key, :binary_id, null: false
      add :aggregate_type,  :string,    null: false
      add :aggregate_id,    :binary_id, null: false
      add :event_type,      :string,    null: false
      add :payload,         :jsonb,     null: false
      add :status,          :outbox_status, null: false, default: "pending"
      add :attempts,        :smallint,  null: false, default: 0
      add :last_error,      :text
      add :processed_at,    :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:outbox_events, [:idempotency_key])
    create index(:outbox_events, [:aggregate_type, :aggregate_id])

    # Broadway/Oban tails this partial index — only pending events
    create index(:outbox_events, [:inserted_at],
      where: "status = 'pending'",
      name:  "outbox_events_pending_idx"
    )
  end

  def down do
    drop table(:outbox_events)
    execute "DROP TYPE IF EXISTS outbox_status"
  end
end
