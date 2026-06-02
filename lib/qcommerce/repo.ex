defmodule Qcommerce.Repo do
  use Ecto.Repo,
    otp_app: :qcommerce,
    adapter: Ecto.Adapters.Postgres
end
