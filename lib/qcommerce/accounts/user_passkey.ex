# lib/qcommerce/accounts/user_passkey.ex
defmodule Qcommerce.Accounts.UserPasskey do
  use Qcommerce.Core.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_passkeys" do
    field :external_id, :binary
    field :public_key, :binary
    field :nickname, :string

    belongs_to :user, Qcommerce.Accounts.User

    timestamps()
  end

  def changeset(user_passkey, attrs) do
    user_passkey
    |> cast(attrs, [:external_id, :public_key, :nickname, :user_id])
    |> validate_required([:external_id, :public_key, :user_id])
    |> unique_constraint(:external_id)
  end
end
