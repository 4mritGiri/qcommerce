# lib/qcommerce/ledger/account.ex
defmodule Qcommerce.Ledger.Account do
  use Qcommerce.Core.Schema

  @account_types ~w(asset liability equity revenue expense)a
  @normal_balances ~w(debit credit)a

  schema "accounts" do
    belongs_to :parent, __MODULE__, foreign_key: :parent_id

    field :code, :string
    field :name, :string
    field :account_type, Ecto.Enum, values: @account_types
    field :normal_balance, Ecto.Enum, values: @normal_balances
    field :shard_count, :integer, default: 1
    field :is_active, :boolean, default: true

    timestamps()
  end

  @required [:code, :name, :account_type, :normal_balance]
  @optional [:parent_id, :shard_count, :is_active]

  def changeset(account, attrs) do
    account
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:shard_count, [1, 2, 4, 8, 16])
    |> validate_normal_balance_consistency()
    |> unique_constraint(:code)
  end

  # Enforce accounting law at the application layer
  # (also enforced at DB layer via CHECK constraint)
  defp validate_normal_balance_consistency(changeset) do
    type = get_field(changeset, :account_type)
    balance = get_field(changeset, :normal_balance)

    valid? =
      (type in [:asset, :expense] and balance == :debit) or
        (type in [:liability, :equity, :revenue] and balance == :credit)

    if type && balance && not valid? do
      add_error(
        changeset,
        :normal_balance,
        "#{type} accounts must have #{expected_balance(type)} normal balance"
      )
    else
      changeset
    end
  end

  defp expected_balance(type) when type in [:asset, :expense], do: "debit"
  defp expected_balance(type) when type in [:liability, :equity, :revenue], do: "credit"
end
