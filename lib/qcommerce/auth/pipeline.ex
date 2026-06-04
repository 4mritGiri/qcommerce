# lib/qcommerce/auth/pipeline.ex
defmodule Qcommerce.Auth.Pipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :qcommerce,
    module: Qcommerce.Auth.Guardian,
    error_handler: Qcommerce.Auth.ErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource, allow_blank: true
end
