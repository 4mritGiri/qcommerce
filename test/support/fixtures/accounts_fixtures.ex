defmodule Qcommerce.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Qcommerce.Accounts` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "some email",
        hashed_password: "some hashed_password",
        name: "some name",
        role: "some role"
      })
      |> Qcommerce.Accounts.create_user()

    user
  end

  @doc """
  Generate a address.
  """
  def address_fixture(attrs \\ %{}) do
    {:ok, address} =
      attrs
      |> Enum.into(%{
        city: "some city",
        country: "some country",
        line1: "some line1"
      })
      |> Qcommerce.Accounts.create_address()

    address
  end
end
