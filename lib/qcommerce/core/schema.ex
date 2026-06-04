defmodule Qcommerce.Core.Schema do
  @moduledoc """
  Base schema macro imported by every Ecto schema in the project.

  ## Why this exists (DRY principle)
  Without this, every schema file repeats:
    - `use Ecto.Schema`
    - `import Ecto.Changeset`
    - `@primary_key {:id, :binary_id, autogenerate: true}`
    - `@foreign_key_type :binary_id`
    - `@timestamps_opts [type: :utc_datetime_usec]`

  With this, every schema file just writes:
    `use Qcommerce.Core.Schema`

  ## Usage
      defmodule Qcommerce.Accounts.User do
        use Qcommerce.Core.Schema

        schema "users" do
          field :email, :string
          timestamps()  # produces inserted_at + updated_at as utc_datetime_usec
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      # All primary keys are UUIDs, never integer sequences.
      # Consistent with our DDL: DEFAULT uuid_generate_v4()
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id

      # Store timestamps as UTC microseconds — critical for the ledger's
      # checkpointed_through boundary comparisons to be precise.
      @timestamps_opts [type: :utc_datetime_usec]
    end
  end
end
