defmodule CargoShipping.Repo do
  use Ecto.Repo,
    otp_app: :cargo_shipping,
    adapter: Ecto.Adapters.Postgres
end
