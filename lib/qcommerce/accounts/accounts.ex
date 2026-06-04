# lib/qcommerce/accounts/accounts.ex

defmodule Qcommerce.Accounts do
  @moduledoc """
  Public context API for identity and authentication.

  Rule: controllers and other contexts call THIS module only.
  No direct Repo access outside this file for users/addresses.
  Every function returns {:ok, result} | {:error, %Core.Error{}}.
  """

  import Ecto.Query

  alias Qcommerce.Repo
  alias Qcommerce.Core.{Error, Query}
  alias Qcommerce.Accounts.{User, Address}

  # ---------------------------------------------------------------------------
  # Users — reads
  # ---------------------------------------------------------------------------

  def get_user(id) do
    case Repo.get(User, id) do
      nil -> {:error, Error.not_found("User", id)}
      user -> {:ok, user}
    end
  end

  def get_user_by_email(email) when is_binary(email) do
    case Repo.get_by(User, email: String.downcase(String.trim(email))) do
      nil -> {:error, Error.not_found("User")}
      user -> {:ok, user}
    end
  end

  def list_users(params \\ []) do
    base =
      User
      |> Query.filter_by(:role, params[:role])
      |> Query.filter_by(:is_active, params[:is_active])
      |> Query.search([:full_name, :email], params[:q])
      |> Query.sort(params[:sort], params[:dir], allowed: [:full_name, :email, :inserted_at])

    total = Repo.aggregate(base, :count)
    {paginated, meta} = Query.paginate(base, page: params[:page], per_page: params[:per_page])

    {:ok, {Repo.all(paginated), Map.put(meta, :total, total)}}
  end

  # ---------------------------------------------------------------------------
  # Users — writes
  # ---------------------------------------------------------------------------

  def create_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> handle_result()
  end

  def update_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
    |> handle_result()
  end

  def change_password(%User{} = user, new_password) do
    user
    |> User.password_changeset(%{password: new_password})
    |> Repo.update()
    |> handle_result()
  end

  def deactivate_user(%User{} = user) do
    user |> User.deactivate_changeset() |> Repo.update() |> handle_result()
  end

  # ---------------------------------------------------------------------------
  # Authentication
  # ---------------------------------------------------------------------------

  def authenticate(email, password) when is_binary(email) and is_binary(password) do
    with {:ok, user} <- get_user_by_email(email),
         true <- user.is_active || :inactive,
         true <- Bcrypt.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      _ ->
        Bcrypt.no_user_verify()
        {:error, Error.unauthorized("Invalid email or password")}
    end
  end

  # ---------------------------------------------------------------------------
  # Addresses
  # ---------------------------------------------------------------------------

  def list_addresses(user_id) do
    addresses =
      Address
      |> Query.for_user(user_id)
      |> order_by([a], desc: a.is_default, asc: a.inserted_at)
      |> Repo.all()

    {:ok, addresses}
  end

  def create_address(%User{} = user, attrs) do
    is_first = Repo.aggregate(Query.for_user(Address, user.id), :count) == 0

    %Address{user_id: user.id}
    |> Address.changeset(Map.put_new(attrs, "is_default", is_first))
    |> Repo.insert()
    |> handle_result()
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp handle_result({:ok, record}), do: {:ok, record}
  defp handle_result({:error, %Ecto.Changeset{} = cs}), do: {:error, Error.validation(cs)}
  defp handle_result({:error, reason}), do: {:error, Error.internal(inspect(reason))}
end
