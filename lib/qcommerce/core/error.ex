defmodule Qcommerce.Core.Error do
  @moduledoc """
  Typed error structs for consistent error handling across all contexts.

  ## Why this exists (DRY principle)
  Without this, every context returns ad-hoc errors:
    {:error, "not found"}
    {:error, :unauthorized}
    {:error, changeset}
    {:error, "order already delivered"}

  Controllers then need case-by-case pattern matching with no guarantee
  of shape. This module standardises the contract between contexts and
  controllers into one predictable structure.

  ## The contract
  Every context function returns either:
    {:ok, result}
    {:error, %Qcommerce.Core.Error{}}

  ## Usage in a context
      alias Qcommerce.Core.Error

      def get_user(id) do
        case Repo.get(User, id) do
          nil  -> {:error, Error.not_found("User", id)}
          user -> {:ok, user}
        end
      end

  ## Usage in a controller
      case Accounts.get_user(id) do
        {:ok, user}    -> json(conn, user)
        {:error, error} -> conn |> put_status(Error.to_http(error)) |> json(Error.to_map(error))
      end
  """

  @type error_type ::
          :not_found
          | :unauthorized
          | :forbidden
          | :validation
          | :conflict
          | :internal
          | :unprocessable

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          details: map() | nil
        }

  defstruct [:type, :message, :details]

  # ---------------------------------------------------------------------------
  # Constructors — one function per error type for readable call sites
  # ---------------------------------------------------------------------------

  @spec not_found(String.t(), any()) :: t()
  def not_found(resource, id \\ nil) do
    %__MODULE__{
      type: :not_found,
      message: "#{resource} not found",
      details: if(id, do: %{id: id}, else: nil)
    }
  end

  @spec unauthorized(String.t()) :: t()
  def unauthorized(message \\ "Authentication required") do
    %__MODULE__{type: :unauthorized, message: message, details: nil}
  end

  @spec forbidden(String.t()) :: t()
  def forbidden(message \\ "You do not have permission to perform this action") do
    %__MODULE__{type: :forbidden, message: message, details: nil}
  end

  @spec validation(Ecto.Changeset.t()) :: t()
  def validation(%Ecto.Changeset{} = changeset) do
    %__MODULE__{
      type: :validation,
      message: "Validation failed",
      details: format_changeset_errors(changeset)
    }
  end

  @spec conflict(String.t()) :: t()
  def conflict(message) do
    %__MODULE__{type: :conflict, message: message, details: nil}
  end

  @spec unprocessable(String.t(), map()) :: t()
  def unprocessable(message, details \\ %{}) do
    %__MODULE__{type: :unprocessable, message: message, details: details}
  end

  @spec internal(String.t()) :: t()
  def internal(message \\ "An internal error occurred") do
    %__MODULE__{type: :internal, message: message, details: nil}
  end

  # ---------------------------------------------------------------------------
  # HTTP mapping — single source of truth for status codes
  # ---------------------------------------------------------------------------

  @spec to_http(t()) :: pos_integer()
  def to_http(%__MODULE__{type: type}) do
    case type do
      :not_found -> 404
      :unauthorized -> 401
      :forbidden -> 403
      :validation -> 422
      :conflict -> 409
      :unprocessable -> 422
      :internal -> 500
    end
  end

  # ---------------------------------------------------------------------------
  # JSON serialization
  # ---------------------------------------------------------------------------

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = error) do
    %{
      error: %{
        type: error.type,
        message: error.message,
        details: error.details
      }
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
