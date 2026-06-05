# lib/qcommerce/catalog/flash_sale.ex
defmodule Qcommerce.Catalog.FlashSale do
  use Qcommerce.Core.Schema

  @moduledoc """
  Flash sales with countdown timers. HomeLive subscribes to a tick
  via :timer.send_interval and calls seconds_remaining/1 to update the UI.

  The countdown is computed server-side and pushed to the client via LiveView,
  so the timer is always accurate even if the client clock is wrong.
  """

  schema "flash_sales" do
    field :label, :string
    field :ends_at, :utc_datetime_usec
    field :discount_pct, :integer, default: 0
    field :is_active, :boolean, default: true

    timestamps()
  end

  @required [:label, :ends_at]
  @optional [:discount_pct, :is_active]

  def changeset(flash, attrs) do
    flash
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:discount_pct,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
  end

  # ---------------------------------------------------------------------------
  # Countdown helpers — called from HomeLive on every tick
  # ---------------------------------------------------------------------------

  @doc "Seconds remaining until flash sale ends. nil if expired or inactive."
  def seconds_remaining(%__MODULE__{is_active: true, ends_at: ends_at}) do
    diff = DateTime.diff(ends_at, DateTime.utc_now())
    if diff > 0, do: diff, else: nil
  end

  def seconds_remaining(_), do: nil

  @doc "Format seconds as '2h 14m 33s'"
  def format_countdown(nil), do: "Expired"

  def format_countdown(secs) do
    h = div(secs, 3600)
    m = div(rem(secs, 3600), 60)
    s = rem(secs, 60)

    cond do
      h > 0 -> "#{h}h #{m}m #{s}s"
      m > 0 -> "#{m}m #{s}s"
      true -> "#{s}s"
    end
  end
end
