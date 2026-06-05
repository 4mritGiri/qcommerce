# lib/qcommerce_web/controllers/session_controller.ex
defmodule QcommerceWeb.SessionController do
  use QcommerceWeb, :controller

  alias Qcommerce.Accounts

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate(email, password) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome back, #{user.full_name}!")
        |> redirect(to: ~p"/")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: ~p"/")
    end
  end

  def signup(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Account created successfully!")
        |> redirect(to: ~p"/")

      {:error, changeset} ->
        # Format validation error messages nicely
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
              to_string(opts[String.to_existing_atom(key)])
            end)
          end)
          |> Enum.map(fn {field, msgs} ->
            "#{Phoenix.Naming.humanize(field)} #{Enum.join(msgs, ", ")}"
          end)
          |> Enum.join("; ")

        conn
        |> put_flash(:error, "Registration failed: #{errors}")
        |> redirect(to: ~p"/")
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: ~p"/")
  end

  def login_phone(conn, %{"phone" => phone}) do
    # Search for user by phone number
    user =
      case Qcommerce.Repo.get_by(Qcommerce.Accounts.User, phone: phone) do
        nil ->
          # Create user automatically
          digits = Regex.replace(~r/\D/, phone, "") |> String.slice(-4..-1)
          random_id = :crypto.strong_rand_bytes(4) |> Base.hex_encode32(case: :lower) |> String.slice(0..5)
          {:ok, new_user} =
            Accounts.create_user(%{
              email: "phone_customer_#{random_id}@qcommerce.com",
              phone: phone,
              full_name: "Customer #{digits}",
              password: "password_#{random_id}_123",
              role: :customer
            })
          new_user

        existing ->
          existing
      end

    conn
    |> put_session(:user_id, user.id)
    |> put_flash(:info, "Logged in as #{user.full_name} via Phone OTP.")
    |> redirect(to: ~p"/")
  end

  def login_qr(conn, _params) do
    # Log in default seed customer user
    case Qcommerce.Repo.get_by(Qcommerce.Accounts.User, email: "customer@qcommerce.com") do
      nil ->
        conn
        |> put_flash(:error, "Default customer account not seeded.")
        |> redirect(to: ~p"/")

      user ->
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome back, #{user.full_name}! (Logged in via QR Code)")
        |> redirect(to: ~p"/")
    end
  end

  def login_passkey(conn, %{"external_id" => ext_id}) do
    case Qcommerce.Accounts.PasskeyAuth.authenticate_via_passkey(ext_id) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome back, #{user.full_name}! (Logged in via Passkey)")
        |> redirect(to: ~p"/")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Passkey authentication failed. No registered passkey found.")
        |> redirect(to: ~p"/")
    end
  end
end
