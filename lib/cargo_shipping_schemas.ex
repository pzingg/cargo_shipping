defmodule CargoShippingSchemas do
  @moduledoc """
  CargoShippingSchemas is a top-level boundary that contains all
  the schema definitions.

  This boundary is defined to ensure that no complex logic, such as
  changeset building or repo operations, creeps into these modules.
  To this end, we’ve placed schemas into this top-level boundary,
  which is not allowed to depend on any other boundary.
  """
  use Boundary, deps: [Ecto, Phoenix.Param], exports: :all
end
