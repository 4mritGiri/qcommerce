# lib/qcommerce/delivery/rider.ex

defmodule Qcommerce.Delivery.Rider do
  use Qcommerce.Core.Schema

  @moduledoc """
  Rider profile linked one-to-one with a User (role = :rider).
  current_location is updated by the hot path (Phoenix Channel/GenServer)
  and persisted here periodically — not on every GPS tick.
  """

  alias Qcommerce.Accounts.User

  @statuses ~w(offline available on_delivery)a
  @vehicles ~w(bicycle motorcycle ev_scooter)a

  schema "riders" do
    belongs_to :user, User

    field :vehicle_type, Ecto.Enum, values: @vehicles, default: :motorcycle
    field :license_number, :string
    field :status, Ecto.Enum, values: @statuses, default: :offline
    field :current_location, Geo.PostGIS.Geometry
    field :location_updated_at, :utc_datetime_usec

    timestamps(updated_at: false)
  end

  @required [:user_id]
  @optional [:vehicle_type, :license_number, :status, :current_location, :location_updated_at]

  def changeset(rider, attrs) do
    rider
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:user_id)
    |> assoc_constraint(:user)
  end

  def location_changeset(rider, %Geo.Point{} = point) do
    rider
    |> change(current_location: point, location_updated_at: DateTime.utc_now())
  end

  def status_changeset(rider, status) when status in @statuses do
    change(rider, status: status)
  end
end
