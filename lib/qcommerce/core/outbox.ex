# lib/qcommerce/core/outbox.ex
defmodule Qcommerce.Core.Outbox do
  @moduledoc """
  Single module responsible for writing events to the outbox_events table.

  Provides two ways to append an outbox event to an Ecto.Multi pipeline:

  1. append/6 — explicit args, used when all values are known upfront:
       multi |> Outbox.append(:evt, order_id, "order", "order.placed", %{})

  2. append/3 — callback form, used inside pipeline steps where the
       aggregate_id comes from a previous Multi step result:
       multi |> Outbox.append(:evt, fn %{order: o} ->
         {o.id, "order", "order.delivered", %{order_id: o.id}}
       end)
  """

  alias Qcommerce.Outbox.OutboxEvent

  @uuid5_namespace UUID.uuid5(:dns, "qcommerce.internal")

  @doc """
  Callback form — extracts args from prior Multi step results via a function.
  The function receives the Multi results map and must return:
    {aggregate_id, aggregate_type, event_type, payload}
  """
  @spec append(Ecto.Multi.t(), atom(), function()) :: Ecto.Multi.t()
  def append(multi, op_name, fun) when is_function(fun, 1) do
    Ecto.Multi.run(multi, op_name, fn repo, results ->
      {aggregate_id, aggregate_type, event_type, payload} = fun.(results)
      insert_event(repo, aggregate_id, aggregate_type, event_type, payload)
    end)
  end

  @doc """
  Explicit form — use when all values are known before Multi runs.
  """
  @spec append(Ecto.Multi.t(), atom(), binary(), String.t(), String.t(), map()) :: Ecto.Multi.t()
  def append(multi, op_name, aggregate_id, aggregate_type, event_type, payload) do
    Ecto.Multi.run(multi, op_name, fn repo, _results ->
      insert_event(repo, aggregate_id, aggregate_type, event_type, payload)
    end)
  end

  @doc "Derives a deterministic UUIDv5 — same inputs always produce the same key."
  @spec derive_idempotency_key(binary(), String.t()) :: String.t()
  def derive_idempotency_key(aggregate_id, event_type) do
    UUID.uuid5(@uuid5_namespace, "#{aggregate_id}:#{event_type}")
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp insert_event(repo, aggregate_id, aggregate_type, event_type, payload) do
    idempotency_key = derive_idempotency_key(aggregate_id, event_type)

    repo.insert(
      %OutboxEvent{
        idempotency_key: idempotency_key,
        aggregate_type:  aggregate_type,
        aggregate_id:    aggregate_id,
        event_type:      event_type,
        payload:         payload,
        status:          :pending,
        attempts:        0
      },
      on_conflict:     :nothing,
      conflict_target: :idempotency_key
    )
  end
end
