# lib/qcommerce_web/channels/user_socket.ex
defmodule QcommerceWeb.UserSocket do
  use Phoenix.Socket

  channel "order:*", QcommerceWeb.OrderChannel
  channel "rider:*", QcommerceWeb.RiderChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case verify_token(token) do
      {:ok, user} ->
        {:ok, assign(socket, :current_user, user)}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"

  # ---

  defp verify_token(token) do
    with {:ok, claims} <- Qcommerce.Auth.Guardian.decode_and_verify(token),
         {:ok, user} <- Qcommerce.Auth.Guardian.resource_from_claims(claims) do
      {:ok, user}
    end
  end
end
