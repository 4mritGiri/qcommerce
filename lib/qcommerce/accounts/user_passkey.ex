# lib/qcommerce/accounts/user_passkey.ex
defmodule Qcommerce.Accounts.UserPasskey do
  use Qcommerce.Core.Schema

  # Core.Schema already sets @primary_key and @foreign_key_type — do not repeat

  schema "user_passkeys" do
    belongs_to :user, Qcommerce.Accounts.User

    field :external_id, :binary
    field :public_key, :binary
    field :nickname, :string

    timestamps()
  end

  def changeset(passkey, attrs) do
    passkey
    |> cast(attrs, [:external_id, :public_key, :nickname, :user_id])
    |> validate_required([:external_id, :public_key, :user_id])
    |> unique_constraint(:external_id)
    |> assoc_constraint(:user)
  end
end
