# lib/qcommerce/platform/fiscal_year.ex

defmodule Qcommerce.Platform.FiscalYear do
  use Qcommerce.Core.Schema

  @moduledoc """
  Defines the accounting period boundary for the ledger.
  Every journal and journal_line is scoped to a fiscal year.
  The CHECK constraint (enforced at the DB layer via trigger)
  guarantees posted_at falls within start_date..end_date.
  """

  schema "fiscal_years" do
    field :label, :string
    field :start_date, :date
    field :end_date, :date
    field :is_closed, :boolean, default: false

    timestamps(updated_at: false)
  end

  @required [:label, :start_date, :end_date]
  @optional [:is_closed]

  def changeset(fiscal_year, attrs) do
    fiscal_year
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_date_order()
    |> unique_constraint(:label)
  end

  def close_changeset(fiscal_year) do
    change(fiscal_year, is_closed: true)
  end

  defp validate_date_order(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    if start_date && end_date && Date.compare(end_date, start_date) != :gt do
      add_error(changeset, :end_date, "must be after start_date")
    else
      changeset
    end
  end
end
