# lib/qcommerce/delivery/delivery.ex
defmodule Qcommerce.Delivery do
  @moduledoc """
  Public context API for rider management and location tracking.
  The hot path (Phoenix Channels) calls update_location/2 on each GPS tick.
  """

  import Ecto.Query

  alias Qcommerce.Repo
  alias Qcommerce.Core.Error
  alias Qcommerce.Delivery.Rider
  alias Qcommerce.Platform.Branch

  def get_rider(id) do
    case Repo.get(Rider, id) do
      nil -> {:error, Error.not_found("Rider", id)}
      rider -> {:ok, rider}
    end
  end

  def get_rider_by_user(user_id) do
    case Repo.get_by(Rider, user_id: user_id) do
      nil -> {:error, Error.not_found("Rider")}
      rider -> {:ok, rider}
    end
  end

  def list_available_riders(branch_id) do
    riders =
      from(r in Rider,
        join: b in Branch,
        on: b.id == ^branch_id,
        where: r.status == :available,
        where:
          fragment(
            "ST_DWithin(?, ?, ?)",
            r.current_location,
            b.location,
            b.catchment_radius_m
          )
      )
      |> Repo.all()

    {:ok, riders}
  end

  def create_rider(user_id, attrs \\ %{}) do
    %Rider{user_id: user_id}
    |> Rider.changeset(Map.put(attrs, "user_id", user_id))
    |> Repo.insert()
    |> handle_result()
  end

  def update_location(%Rider{} = rider, %Geo.Point{} = point) do
    rider
    |> Rider.location_changeset(point)
    |> Repo.update()
    |> handle_result()
  end

  def update_status(%Rider{} = rider, status) do
    rider
    |> Rider.status_changeset(status)
    |> Repo.update()
    |> handle_result()
  end

  defp handle_result({:ok, record}), do: {:ok, record}
  defp handle_result({:error, %Ecto.Changeset{} = cs}), do: {:error, Error.validation(cs)}
  defp handle_result({:error, reason}), do: {:error, Error.internal(inspect(reason))}
end
