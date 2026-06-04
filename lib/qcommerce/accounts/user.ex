# lib/qcommerce/accounts/user.ex
defmodule Qcommerce.Accounts.User do
  use Qcommerce.Core.Schema

  @moduledoc """
  User schema. One table covers all roles: customer, picker,
  rider, branch_manager, super_admin.
  password_hash is stripped from JSON responses via the Jason.Encoder impl.
  """

  alias Qcommerce.Accounts.Address

  @roles ~w(customer picker rider branch_manager super_admin)a

  schema "users" do
    field :email, :string
    field :phone, :string
    field :full_name, :string
    field :password_hash, :string
    field :role, Ecto.Enum, values: @roles, default: :customer
    field :is_active, :boolean, default: true

    # Virtual — accepted at the changeset layer, hashed, never persisted raw
    field :password, :string, virtual: true

    has_many :addresses, Address, foreign_key: :user_id

    timestamps()
  end

  # ---------------------------------------------------------------------------
  # Changesets — one per use case
  # ---------------------------------------------------------------------------

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :phone, :full_name, :password, :role])
    |> validate_required([:email, :phone, :full_name, :password])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: "must be a valid email")
    |> validate_format(:phone, ~r/^\+?[0-9]{8,15}$/, message: "must be a valid phone number")
    |> validate_length(:password, min: 8, message: "must be at least 8 characters")
    |> validate_inclusion(:role, @roles)
    |> unique_constraint(:email)
    |> unique_constraint(:phone)
    |> hash_password()
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:full_name, :phone])
    |> validate_required([:full_name])
    |> validate_format(:phone, ~r/^\+?[0-9]{8,15}$/)
    |> unique_constraint(:phone)
  end

  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8)
    |> hash_password()
  end

  def deactivate_changeset(user), do: change(user, is_active: false)

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp hash_password(%Ecto.Changeset{valid?: true} = changeset) do
    case fetch_change(changeset, :password) do
      {:ok, password} ->
        changeset
        |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
        |> delete_change(:password)

      :error ->
        changeset
    end
  end

  defp hash_password(changeset), do: changeset

  # Strip password_hash from all JSON API responses
  defimpl Jason.Encoder, for: __MODULE__ do
    def encode(user, opts) do
      user
      |> Map.from_struct()
      |> Map.drop([:password_hash, :password, :__meta__])
      |> Jason.Encode.map(opts)
    end
  end
end
