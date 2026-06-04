# lib/qcommerce/ledger/balance_checkpoint.ex
defmodule Qcommerce.Ledger.BalanceCheckpoint do
  use Qcommerce.Core.Schema

  @moduledoc """
  Insert-only materialized balance cache.
  Written exclusively by the Oban checkpoint job every 15 minutes.
  Stores CUMULATIVE totals so a balance query needs only:
    latest_checkpoint + delta(journal_lines since checkpointed_through)
  Never updated in place — each checkpoint is a new row.
  """

  alias Qcommerce.Platform.{Branch, FiscalYear}
  alias Qcommerce.Ledger.Account

  schema "balance_checkpoints" do
    belongs_to :branch, Branch
    belongs_to :account, Account
    belongs_to :fiscal_year, FiscalYear

    field :shard_id, :integer, default: 0
    field :debit_total, :decimal, default: 0
    field :credit_total, :decimal, default: 0
    field :checkpointed_through, :utc_datetime_usec
    field :entry_count, :integer, default: 0

    timestamps(updated_at: false)
  end

  @required [:branch_id, :account_id, :fiscal_year_id, :checkpointed_through]
  @optional [:shard_id, :debit_total, :credit_total, :entry_count]

  def changeset(checkpoint, attrs) do
    checkpoint
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:shard_id, Enum.to_list(0..15))
  end
end
