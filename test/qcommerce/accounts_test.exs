defmodule Qcommerce.AccountsTest do
  use Qcommerce.DataCase

  alias Qcommerce.Accounts

  describe "accounts" do
    alias Qcommerce.Accounts.User

    import Qcommerce.AccountsFixtures

    @invalid_attrs %{name: nil, role: nil, email: nil, hashed_password: nil}

    test "list_accounts/0 returns all accounts" do
      user = user_fixture()
      assert Accounts.list_accounts() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{name: "some name", role: "some role", email: "some email", hashed_password: "some hashed_password"}

      assert {:ok, %User{} = user} = Accounts.create_user(valid_attrs)
      assert user.name == "some name"
      assert user.role == "some role"
      assert user.email == "some email"
      assert user.hashed_password == "some hashed_password"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      update_attrs = %{name: "some updated name", role: "some updated role", email: "some updated email", hashed_password: "some updated hashed_password"}

      assert {:ok, %User{} = user} = Accounts.update_user(user, update_attrs)
      assert user.name == "some updated name"
      assert user.role == "some updated role"
      assert user.email == "some updated email"
      assert user.hashed_password == "some updated hashed_password"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user == Accounts.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end

  describe "addresses" do
    alias Qcommerce.Accounts.Address

    import Qcommerce.AccountsFixtures

    @invalid_attrs %{line1: nil, city: nil, country: nil}

    test "list_addresses/0 returns all addresses" do
      address = address_fixture()
      assert Accounts.list_addresses() == [address]
    end

    test "get_address!/1 returns the address with given id" do
      address = address_fixture()
      assert Accounts.get_address!(address.id) == address
    end

    test "create_address/1 with valid data creates a address" do
      valid_attrs = %{line1: "some line1", city: "some city", country: "some country"}

      assert {:ok, %Address{} = address} = Accounts.create_address(valid_attrs)
      assert address.line1 == "some line1"
      assert address.city == "some city"
      assert address.country == "some country"
    end

    test "create_address/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_address(@invalid_attrs)
    end

    test "update_address/2 with valid data updates the address" do
      address = address_fixture()
      update_attrs = %{line1: "some updated line1", city: "some updated city", country: "some updated country"}

      assert {:ok, %Address{} = address} = Accounts.update_address(address, update_attrs)
      assert address.line1 == "some updated line1"
      assert address.city == "some updated city"
      assert address.country == "some updated country"
    end

    test "update_address/2 with invalid data returns error changeset" do
      address = address_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_address(address, @invalid_attrs)
      assert address == Accounts.get_address!(address.id)
    end

    test "delete_address/1 deletes the address" do
      address = address_fixture()
      assert {:ok, %Address{}} = Accounts.delete_address(address)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_address!(address.id) end
    end

    test "change_address/1 returns a address changeset" do
      address = address_fixture()
      assert %Ecto.Changeset{} = Accounts.change_address(address)
    end
  end
end
