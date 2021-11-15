defmodule CargoShipping.Infra do
  @moduledoc """
  CargoShipping.Infra a "sink" boundary, which means that everything
  else in the parent CargoShipping core boundary depends on it.
  This boundary contains modules that support access to infrastructural
  services, such as AWS. The infra boundary also contains the Ecto repo.
  """
  use Boundary, deps: [], exports: [Repo]
end
