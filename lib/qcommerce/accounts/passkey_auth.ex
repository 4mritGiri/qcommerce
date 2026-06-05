# lib/qcommerce/accounts/passkey_auth.ex
defmodule Qcommerce.Accounts.PasskeyAuth do
  @moduledoc """
  WebAuthn passkeys helper logic.
  Using Base64URL for transport and verification logic.
  """
  alias Qcommerce.Repo
  alias Qcommerce.Accounts.UserPasskey

  @doc """
  Generates challenge for registration or authentication.
  """
  def generate_challenge do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  @doc """
  Registers a new passkey for a user.
  """
  def register_passkey(user, external_id_b64, public_key_b64, nickname \\ "My Phone") do
    external_id = Base.url_decode64!(external_id_b64, padding: false)
    public_key = Base.url_decode64!(public_key_b64, padding: false)

    %UserPasskey{}
    |> UserPasskey.changeset(%{
      user_id: user.id,
      external_id: external_id,
      public_key: public_key,
      nickname: nickname
    })
    |> Repo.insert()
  end

  @doc """
  Authenticates a user via passkey external_id.
  """
  def authenticate_via_passkey(external_id_b64) do
    external_id = Base.url_decode64!(external_id_b64, padding: false)

    case Repo.get_by(UserPasskey, external_id: external_id) |> Repo.preload(:user) do
      nil -> {:error, :not_found}
      passkey -> {:ok, passkey.user}
    end
  end
end
