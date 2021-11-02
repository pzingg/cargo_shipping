defmodule CargoShipping.RoutingService do
  @moduledoc """
  A module that builds new routes.
  """
  alias CargoShipping.RoutingService.{LibgraphRouteFinder, RandomRouteFinder}

  def find_itineraries(origin, destination, opts) do
    if Keyword.get(opts, :algorithm, :random) == :random do
      RandomRouteFinder.find_itineraries(origin, destination, opts)
    else
      LibgraphRouteFinder.find_itineraries(origin, destination, opts)
    end
  end
end
