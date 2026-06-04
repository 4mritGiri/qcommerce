# lib/qcommerce_web/controllers/fallback_controller.ex
defmodule QcommerceWeb.FallbackController do
  @moduledoc """
  Handles {:error, %Core.Error{}} returns from contexts.
  Every action controller uses `action_fallback QcommerceWeb.FallbackController`
  so error handling is defined ONCE here, not in every controller action.

  DRY principle: without this, every controller action would need its own
  error pattern matching. With this, controllers only handle the happy path.
  """
  use QcommerceWeb, :controller

  alias Qcommerce.Core.Error

  # Typed error struct from any context
  def call(conn, {:error, %Error{} = error}) do
    conn
    |> put_status(Error.to_http(error))
    |> put_view(json: QcommerceWeb.ErrorJSON)
    |> render(:"#{Error.to_http(error)}", error: error)
  end

  # Ecto changeset leaked directly (shouldn't happen if contexts wrap properly)
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    error = Error.validation(changeset)

    conn
    |> put_status(422)
    |> put_view(json: QcommerceWeb.ErrorJSON)
    |> render(:"422", error: error)
  end

  # Catch-all
  def call(conn, {:error, reason}) do
    conn
    |> put_status(500)
    |> put_view(json: QcommerceWeb.ErrorJSON)
    |> render(:"500", error: Error.internal(inspect(reason)))
  end
end
