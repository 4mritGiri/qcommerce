defmodule Qcommerce.Settings do
  @moduledoc """
  System-wide settings context. Settings are stored as string key-value pairs
  in the database and cached in ETS for fast reads.
  """
  import Ecto.Query
  alias Qcommerce.Repo
  alias Qcommerce.Settings.SystemSetting

  @cache_table :qcommerce_settings

  # ---------------------------------------------------------------------------
  # ETS cache bootstrap (called from Application start or first use)
  # ---------------------------------------------------------------------------

  def ensure_cache do
    case :ets.whereis(@cache_table) do
      :undefined ->
        :ets.new(@cache_table, [:set, :public, :named_table, read_concurrency: true])
        reload_cache()
      _ ->
        :ok
    end
  end

  def reload_cache do
    ensure_table_exists()
    settings = Repo.all(SystemSetting)
    Enum.each(settings, fn s ->
      :ets.insert(@cache_table, {s.key, s.value})
    end)
    :ok
  end

  defp ensure_table_exists do
    if :ets.whereis(@cache_table) == :undefined do
      :ets.new(@cache_table, [:set, :public, :named_table, read_concurrency: true])
    end
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Get a setting value (string). Returns `default` if not set."
  def get(key, default \\ nil) do
    ensure_table_exists()
    case :ets.lookup(@cache_table, key) do
      [{^key, value}] -> value
      [] ->
        case Repo.get_by(SystemSetting, key: key) do
          nil -> default
          setting ->
            :ets.insert(@cache_table, {key, setting.value})
            setting.value
        end
    end
  end

  @doc "Get a boolean setting."
  def get_bool(key, default \\ false) do
    get(key, to_string(default)) == "true"
  end

  @doc "Update or create a setting. Busts the ETS cache entry."
  def set(key, value) do
    ensure_table_exists()
    result =
      case Repo.get_by(SystemSetting, key: key) do
        nil ->
          %SystemSetting{}
          |> SystemSetting.changeset(%{key: key, value: to_string(value)})
          |> Repo.insert()

        existing ->
          existing
          |> SystemSetting.changeset(%{value: to_string(value)})
          |> Repo.update()
      end

    case result do
      {:ok, _setting} ->
        :ets.insert(@cache_table, {key, to_string(value)})
        :ok
      {:error, _} = err -> err
    end
  end

  @doc "List all settings in a group."
  def list_by_group(group) do
    Repo.all(from s in SystemSetting, where: s.group == ^group, order_by: s.key)
  end

  @doc "List all settings."
  def list_all do
    Repo.all(from s in SystemSetting, order_by: [s.group, s.key])
  end

  # ---------------------------------------------------------------------------
  # Auth-method helpers (used by HomeLive)
  # ---------------------------------------------------------------------------

  @doc """
  Returns a map of which authentication methods are enabled.
  E.g. %{qr: false, phone: true, email: true, passkey: false}
  """
  def auth_methods do
    %{
      qr:      get_bool("auth_qr_enabled", false),
      phone:   get_bool("auth_phone_enabled", false),
      email:   get_bool("auth_email_enabled", true),
      passkey: get_bool("auth_passkey_enabled", false)
    }
  end

  # ---------------------------------------------------------------------------
  # Default settings (called from seeds)
  # ---------------------------------------------------------------------------

  def seed_defaults do
    defaults = [
      # Auth methods
      %{key: "auth_email_enabled",   value: "true",  label: "Email/Password Login",   group: "auth",    description: "Allow users to log in with email and password."},
      %{key: "auth_phone_enabled",   value: "false", label: "Phone OTP Login",        group: "auth",    description: "Allow users to log in with a phone number and OTP."},
      %{key: "auth_qr_enabled",      value: "false", label: "QR Code Login",          group: "auth",    description: "Allow users to scan a QR code from the mobile app."},
      %{key: "auth_passkey_enabled", value: "false", label: "Passkey Login",          group: "auth",    description: "Allow users to authenticate with a FIDO2 passkey."},
      # General
      %{key: "signup_enabled",       value: "true",  label: "Allow New Registrations", group: "general", description: "If disabled, new sign-ups are blocked."},
      %{key: "guest_checkout",       value: "true",  label: "Guest Checkout",          group: "general", description: "Allow users to shop without registering."},
    ]

    Enum.each(defaults, fn attrs ->
      unless Repo.get_by(SystemSetting, key: attrs.key) do
        %SystemSetting{} |> SystemSetting.changeset(attrs) |> Repo.insert!()
      end
    end)

    reload_cache()
  end
end
