# lib/qcommerce/core/outbox_event.ex

defmodule Qcommerce.Outbox.OutboxEvent do
  use Qcommerce.Core.Schema

  schema "outbox_events" do
    field :idempotency_key, Ecto.UUID
    field :aggregate_type, :string
    field :aggregate_id, Ecto.UUID
    field :event_type, :string
    field :payload, :map

    field :status, Ecto.Enum,
      values: [:pending, :processing, :processed, :failed],
      default: :pending

    field :attempts, :integer, default: 0
    field :last_error, :string
    field :processed_at, :utc_datetime_usec

    timestamps(updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :idempotency_key,
      :aggregate_type,
      :aggregate_id,
      :event_type,
      :payload,
      :status,
      :attempts,
      :last_error
    ])
    |> validate_required([:idempotency_key, :aggregate_type, :aggregate_id, :event_type, :payload])
    |> unique_constraint(:idempotency_key)
  end
end
