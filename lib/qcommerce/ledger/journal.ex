# lib/qcommerce/ledger/journal.ex
defmodule Qcommerce.Ledger.Journal do
  use Qcommerce.Core.Schema

  @moduledoc """
  One journal = one atomic business event (order placed, delivered, cancelled).
  Double-entry balance is enforced across all associated journal_lines
  by a DEFERRED constraint trigger at the DB layer.
  """

  alias Qcommerce.Platform.{Branch, FiscalYear}
  alias Qcommerce.Ledger.JournalLine
  alias Qcommerce.Outbox.OutboxEvent

  schema "journals" do
    belongs_to :branch, Branch
    belongs_to :fiscal_year, FiscalYear
    belongs_to :outbox_event, OutboxEvent

    field :idempotency_key, Ecto.UUID
    field :description, :string
    field :posted_at, :utc_datetime_usec

    has_many :journal_lines, JournalLine

    timestamps(updated_at: false)
  end

  @required [:branch_id, :fiscal_year_id, :idempotency_key, :posted_at]
  @optional [:description, :outbox_event_id]

  def changeset(journal, attrs) do
    journal
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:idempotency_key)
    |> assoc_constraint(:branch)
    |> assoc_constraint(:fiscal_year)
  end
end
