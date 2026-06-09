# lib/qcommerce_web/controllers/session_controller.ex
defmodule QcommerceWeb.SessionController do
  use QcommerceWeb, :controller

  alias QcommerceWeb.Paths
  alias Qcommerce.Repo
  alias Qcommerce.Accounts.User

  alias Qcommerce.Accounts
  alias Qcommerce.Accounts.PasskeyAuth
  alias Qcommerce.Cart.CartSession

  # ---------------------------------------------------------------------------
  # Email / Password login
  # ---------------------------------------------------------------------------

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate(email, password) do
      {:ok, user} ->
        conn
        |> login_user(user)
        |> put_flash(:info, "Welcome back, #{user.full_name}!")
        |> redirect(to: Paths.home())

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: Paths.home())
    end
  end

  # ---------------------------------------------------------------------------
  # Sign up
  # ---------------------------------------------------------------------------

  def signup(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> login_user(user)
        |> put_flash(:info, "Account created! Welcome to QCommerce 🎉")
        |> redirect(to: Paths.home())

      {:error, changeset} ->
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
        |> redirect(to: Paths.home())
    end
  end

  # ---------------------------------------------------------------------------
  # Logout
  # ---------------------------------------------------------------------------

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: Paths.home())
  end

  # ---------------------------------------------------------------------------
  # Phone OTP login
  # ---------------------------------------------------------------------------

  def login_phone(conn, %{"phone" => raw_phone}) do
    phone =
      raw_phone
      |> String.trim()

    user =
      case Repo.get_by(User, phone: phone) do
        nil ->
          digits =
            phone
            |> Regex.replace(~r/\D/, "")
            |> String.slice(-4, 4)

          random_id =
            :crypto.strong_rand_bytes(4)
            |> Base.hex_encode32(case: :lower)
            |> String.slice(0, 6)

          case Accounts.create_user(%{
                 "email" => "phone_#{random_id}@qcommerce.com",
                 "phone" => phone,
                 "full_name" => "Customer #{digits}",
                 "password" => "phone_pass_#{random_id}_!",
                 "role" => "customer"
               }) do
            {:ok, user} ->
              user

            {:error, error} ->
              raise "Phone user creation failed: #{inspect(error)}"
          end

        user ->
          user
      end

    conn
    |> login_user(user)
    |> put_flash(:info, "Welcome, #{user.full_name}!")
    |> redirect(to: Paths.home())
  end

  # ---------------------------------------------------------------------------
  # QR login (simulated)
  # ---------------------------------------------------------------------------

  def login_qr(conn, _params) do
    case Qcommerce.Repo.get_by(Qcommerce.Accounts.User, email: "customer@qcommerce.com") do
      nil ->
        conn
        |> put_flash(:error, "Default customer account not found. Run seeds.")
        |> redirect(to: Paths.home())

      user ->
        conn
        |> login_user(user)
        |> put_flash(:info, "Welcome back! (QR login)")
        |> redirect(to: Paths.home())
    end
  end

  # ---------------------------------------------------------------------------
  # Passkey — legacy simulate (dev only)
  # ---------------------------------------------------------------------------

  def login_passkey(conn, %{"external_id" => ext_id}) do
    case PasskeyAuth.authenticate_via_passkey(ext_id) do
      {:ok, user} ->
        conn
        |> login_user(user)
        |> put_flash(:info, "Welcome back, #{user.full_name}! (Passkey)")
        |> redirect(to: Paths.home())

      {:error, _} ->
        conn
        |> put_flash(:error, "Passkey not recognised.")
        |> redirect(to: Paths.home())
    end
  end

  # ---------------------------------------------------------------------------
  # WebAuthn — Registration flow
  # ---------------------------------------------------------------------------

  @doc """
  GET /session/passkey/registration_options
  Returns JSON options for navigator.credentials.create()
  """
  def passkey_registration_options(conn, _params) do
    user_id = get_session(conn, :user_id)

    with true <- is_binary(user_id) || {:error, :not_logged_in},
         {:ok, user} <- Accounts.get_user(user_id) do
      challenge = PasskeyAuth.generate_challenge()
      options = PasskeyAuth.registration_options(user, challenge)

      conn
      |> put_session(:passkey_challenge, challenge)
      |> put_session(:passkey_flow, "registration")
      |> json(options)
    else
      {:error, :not_logged_in} ->
        conn |> put_status(401) |> json(%{error: "Login required to register a passkey"})

      {:error, _} ->
        conn |> put_status(404) |> json(%{error: "User not found"})
    end
  end

  @doc """
  POST /session/passkey/register
  Verifies the credential from the browser and stores the passkey.
  Body: { credential: <PublicKeyCredential JSON>, nickname: "string" }
  """
  def passkey_register(conn, %{"credential" => credential} = params) do
    user_id = get_session(conn, :user_id)
    challenge = get_session(conn, :passkey_challenge)
    nickname = params["nickname"] || "My Passkey"

    with true <- is_binary(user_id) || {:error, :not_logged_in},
         true <- is_binary(challenge) || {:error, :no_challenge},
         {:ok, user} <- Accounts.get_user(user_id),
         {:ok, _passkey} <- PasskeyAuth.verify_registration(user, credential, challenge, nickname) do
      conn
      |> delete_session(:passkey_challenge)
      |> put_status(200)
      |> json(%{ok: true, message: "Passkey registered successfully"})
    else
      {:error, :not_logged_in} ->
        conn |> put_status(401) |> json(%{error: "Not logged in"})

      {:error, :no_challenge} ->
        conn |> put_status(400) |> json(%{error: "No challenge in session"})

      {:error, :already_registered} ->
        conn |> put_status(409) |> json(%{error: "This passkey is already registered"})

      {:error, {:wrong_origin, origin}} ->
        conn |> put_status(400) |> json(%{error: "Wrong origin: #{origin}"})

      {:error, :challenge_mismatch} ->
        conn |> put_status(400) |> json(%{error: "Challenge mismatch — possible replay attack"})

      {:error, reason} ->
        conn |> put_status(400) |> json(%{error: inspect(reason)})
    end
  end

  @doc """
  GET /session/passkey/authentication_options
  Returns JSON options for navigator.credentials.get()
  """
  def passkey_authentication_options(conn, params) do
    # Optional: if email is provided, scope to that user's credentials
    user =
      case params["email"] do
        nil ->
          nil

        email ->
          case Accounts.get_user_by_email(email) do
            {:ok, u} -> u
            _ -> nil
          end
      end

    challenge = PasskeyAuth.generate_challenge()
    options = PasskeyAuth.authentication_options(challenge, user)

    conn
    |> put_session(:passkey_challenge, challenge)
    |> put_session(:passkey_flow, "authentication")
    |> json(options)
  end

  @doc """
  POST /session/passkey/authenticate
  Verifies the assertion from the browser and creates a session.
  Body: { credential: <PublicKeyCredential JSON> }
  """
  def passkey_authenticate(conn, %{"credential" => credential}) do
    challenge = get_session(conn, :passkey_challenge)

    with true <- is_binary(challenge) || {:error, :no_challenge},
         {:ok, user} <- PasskeyAuth.verify_authentication(credential, challenge) do
      conn
      |> delete_session(:passkey_challenge)
      |> login_user(user)
      |> put_flash(:info, "Welcome back, #{user.full_name}!")
      |> json(%{ok: true, redirect: "/"})
    else
      {:error, :no_challenge} ->
        conn |> put_status(400) |> json(%{error: "No challenge in session"})

      {:error, :passkey_not_found} ->
        conn |> put_status(401) |> json(%{error: "Passkey not found — please register first"})

      {:error, :challenge_mismatch} ->
        conn |> put_status(400) |> json(%{error: "Challenge mismatch"})

      {:error, reason} ->
        conn |> put_status(401) |> json(%{error: inspect(reason)})
    end
  end

  @doc """
  POST /session/passkey/authenticate  (form submission from PasskeyHook)
  Accepts the serialised WebAuthn credential, saves guest cart, verifies, logs in.
  """
  def passkey_authenticate_form(conn, %{"credential" => credential_json} = params) do
    challenge = get_session(conn, :passkey_challenge)

    # Save guest cart if present
    conn =
      case params["guest_cart"] do
        nil -> conn
        cart_json -> put_session(conn, CartSession.guest_cart_key(), cart_json)
      end

    with true <- is_binary(challenge) || {:error, :no_challenge},
         {:ok, credential} <- Jason.decode(credential_json),
         {:ok, user} <- PasskeyAuth.verify_authentication(credential, challenge) do
      conn
      |> delete_session(:passkey_challenge)
      |> login_user(user)
      |> put_flash(:info, "Welcome back, #{user.full_name}! (Passkey)")
      |> redirect(to: Paths.home())
    else
      {:error, :no_challenge} ->
        conn
        |> put_flash(:error, "Session expired. Please try again.")
        |> redirect(to: Paths.home())

      {:error, :passkey_not_found} ->
        conn
        |> put_flash(:error, "Passkey not recognised. Please register it first.")
        |> redirect(to: Paths.home())

      _ ->
        conn |> put_flash(:error, "Passkey authentication failed.") |> redirect(to: Paths.home())
    end
  end

  # ---------------------------------------------------------------------------
  # Private — login_user/2 (shared by all auth paths)
  # ---------------------------------------------------------------------------

  # Reads guest cart from session, merges it with any existing user cart,
  # then puts merged cart back so HomeLive can load it on mount.
  defp login_user(conn, user) do
    guest_cart_json = get_session(conn, CartSession.guest_cart_key())
    _guest_cart = CartSession.decode_cart(guest_cart_json)

    conn
    |> put_session(:user_id, user.id)
    # HomeLive reads this on mount
    |> put_session(:merged_guest_cart, guest_cart_json)
    |> delete_session(CartSession.guest_cart_key())
  end

  @doc """
  POST /session/save_guest_cart
  Saves the guest cart JSON into Plug.Session, then redirects to the auth endpoint.
  Called by the GuestCartBridge JS hook before any login redirect.
  """
  def save_guest_cart(conn, %{"guest_cart" => cart_json, "redirect_to" => redirect_to}) do
    safe_redirect =
      if String.starts_with?(redirect_to, "/") and not String.contains?(redirect_to, "//"),
        do: redirect_to,
        else: "/"

    conn
    |> put_session(CartSession.guest_cart_key(), cart_json)
    |> redirect(to: safe_redirect)
  end

  def save_guest_cart(conn, %{"redirect_to" => redirect_to}) do
    safe_redirect =
      if String.starts_with?(redirect_to, "/"), do: redirect_to, else: "/"

    conn |> redirect(to: safe_redirect)
  end
end
