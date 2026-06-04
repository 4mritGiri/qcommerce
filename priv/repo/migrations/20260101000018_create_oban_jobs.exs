# priv/repo/migrations/20260101000018_create_oban_jobs.exs
defmodule Qcommerce.Repo.Migrations.CreateObanJobs do
  use Ecto.Migration

  def up do
    Oban.Migration.up(version: 12)
  end

  def down do
    Oban.Migration.down(version: 1)
  end
end
