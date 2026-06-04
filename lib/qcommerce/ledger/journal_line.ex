# lib/qcommerce/ledger/journal_line.ex
defmodule Qcommerce.Ledger.JournalLine do
  use Qcommerce.Core.Schema

  @moduledoc """
  A single debit or credit entry in the ledger.
  Immutable once written — corrections are made via reversal journals.
  amount is always positive; entry_type carries direction.
  """

  alias Qcommerce.Ledger.{Journal, Account}
  alias Qcommerce.Platform.{Branch, FiscalYear}

  @entry_types ~w(debit credit)a

  schema "journal_lines" do
    belongs_to :journal, Journal
    belongs_to :branch, Branch
    belongs_to :fiscal_year, FiscalYear
    belongs_to :account, Account

    field :amount, :decimal
    field :entry_type, Ecto.Enum, values: @entry_types
    field :shard_id, :integer, default: 0
    field :idempotency_key, Ecto.UUID
    field :posted_at, :utc_datetime_usec

    timestamps(updated_at: false)
  end

  @required [
    :journal_id,
    :branch_id,
    :fiscal_year_id,
    :account_id,
    :amount,
    :entry_type,
    :idempotency_key,
    :posted_at
  ]
  @optional [:shard_id]

  def changeset(line, attrs) do
    line
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:shard_id, Enum.to_list(0..15))
    |> unique_constraint([:idempotency_key, :branch_id, :fiscal_year_id])
  end

  @doc """
  Computes shard_id from order_id for high-frequency accounts.
  For accounts with shard_count=1 this always returns 0.
  """
  def compute_shard_id(order_id, shard_count) when shard_count > 1 do
    :erlang.phash2(order_id, shard_count)
  end

  def compute_shard_id(_order_id, 1), do: 0
end
