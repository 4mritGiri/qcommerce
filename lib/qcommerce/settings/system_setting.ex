# lib/qcommerce/settings/system_setting.ex
defmodule Qcommerce.Settings.SystemSetting do
  use Qcommerce.Core.Schema

  # Core.Schema already sets @primary_key {:id, :binary_id, autogenerate: true}
  # Do NOT repeat it here — it causes a double-definition compile warning

  schema "system_settings" do
    field :key,         :string
    field :value,       :string
    field :label,       :string
    field :description, :string
    field :group,       :string, default: "general"

    timestamps()
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value, :label, :description, :group])
    |> validate_required([:key, :value])
    |> unique_constraint(:key)
  end
end
