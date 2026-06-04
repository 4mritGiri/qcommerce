# lib/qcommerce_web/controllers/error_json.ex
defmodule QcommerceWeb.ErrorJSON do
  alias Qcommerce.Core.Error

  def render(_template, %{error: %Error{} = error}) do
    %{
      error: %{
        type: error.type,
        message: error.message,
        details: error.details
      }
    }
  end

  def render(template, _assigns) do
    %{error: %{type: :error, message: Phoenix.Controller.status_message_from_template(template)}}
  end
end
