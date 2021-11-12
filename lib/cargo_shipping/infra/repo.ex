defmodule CargoShipping.Infra.Repo do
  @moduledoc """
  A sub-boundary for the database infrastructure.
  """
  use Ecto.Repo,
    otp_app: :cargo_shipping,
    adapter: Ecto.Adapters.Postgres
end
