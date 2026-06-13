defmodule Mix.Tasks.CreateSuperuser do
  use Mix.Task

  alias Qcommerce.Accounts.User
  alias Qcommerce.Repo

  def run([email, phone, full_name, password]) do
    Mix.Task.run("app.start")

    attrs = %{
      email: email,
      phone: phone,
      full_name: full_name,
      password: password,
      role: :super_admin
    }

    case %User{}
         |> User.registration_changeset(attrs)
         |> Repo.insert() do
      {:ok, user} ->
        Mix.shell().info("Created #{user.email}")

      {:error, changeset} ->
        IO.inspect(changeset.errors)
    end
  end

  def run(_) do
    Mix.shell().error("""
    Usage:

      mix create_superuser EMAIL PHONE NAME PASSWORD

    Example:

      mix create_superuser admin@example.com +9779800000000 "System Admin" secret123
    """)
  end
end
