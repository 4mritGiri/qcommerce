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
end
