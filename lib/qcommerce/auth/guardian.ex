# lib/qcommerce/auth/guardian.ex
defmodule Qcommerce.Auth.Guardian do
  use Guardian, otp_app: :qcommerce

  alias Qcommerce.Accounts

  def subject_for_token(%{id: id}, _claims), do: {:ok, to_string(id)}
  def subject_for_token(_, _), do: {:error, :invalid_resource}

  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      {:ok, user} -> {:ok, user}
      {:error, _} -> {:error, :resource_not_found}
    end
  end

  def resource_from_claims(_), do: {:error, :invalid_claims}
end
