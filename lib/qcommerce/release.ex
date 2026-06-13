defmodule Qcommerce.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :qcommerce

  alias Qcommerce.Repo
  alias Qcommerce.Accounts.User

  # ---------------------------
  # MIGRATE
  # ---------------------------
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  # ---------------------------
  # ROLLBACK
  # ---------------------------
  def rollback(repo, version) do
    load_app()

    {:ok, _, _} =
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  # ---------------------------
  # SEED (all data)
  # ---------------------------
  def seed do
    load_app()

    seed_admin()
    IO.puts("🌱 Seeding completed")
  end

  # ---------------------------
  # CREATE SUPERUSER (Django-like)
  # ---------------------------
  def create_superuser(email, phone, name, password) do
    load_app()

    %User{}
    |> User.registration_changeset(%{
      email: email,
      phone: phone,
      full_name: name,
      password: password,
      role: :super_admin
    })
    |> Repo.insert()
  end

  # ---------------------------
  # INTERNAL ADMIN SEED
  # ---------------------------
  defp seed_admin do
    Repo.get_by(User, email: "admin@qcom.bizpro.com.np") ||
      %User{}
      |> User.registration_changeset(%{
        email: "admin@qcom.bizpro.com.np",
        phone: "+9779800000000",
        full_name: "System Admin",
        password: "SuperAdmin123",
        role: :super_admin
      })
      |> Repo.insert()
  end

  # ---------------------------
  # HELPERS
  # ---------------------------
  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.ensure_all_started(:logger)
    Application.ensure_all_started(:crypto)

    Application.load(@app)
    Application.ensure_all_started(@app)
  end
end
