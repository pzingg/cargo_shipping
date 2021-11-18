defmodule CargoShippingSchemas.RouteCandidate do
  @moduledoc """
  A found route (itinerary), together with its cost metric. The lowest
  cost route is assumed to be the best candidate.
  """
  @enforce_keys [:itinerary, :cost]
  defstruct [:itinerary, :cost]
end
