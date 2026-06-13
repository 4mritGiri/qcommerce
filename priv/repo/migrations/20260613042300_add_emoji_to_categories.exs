defmodule Qcommerce.Repo.Migrations.AddEmojiToCategories do
  use Ecto.Migration

  def change do
    alter table(:categories) do
      add :emoji, :string
    end
  end
end
