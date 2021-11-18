defmodule CargoShipping.RoutingService do
  @moduledoc """
  A module that builds routes (itineraries).
  """
  alias CargoShipping.RoutingService.{LibgraphRouteFinder, RandomRouteFinder}

  @doc """
  Uses one of two algorithms to find itineraries that match the given
  route specification.

  Returns a (possibly empty) list of `ranked_route` items (maps with
  `:itinerary` and `cost` elements), sorted by least cost first.

  `opts` is a keyword list with this options:

    `:algorithm` - either `:random` (the default; to use the original
      dddsample algorithm), or `:libgraph` (to use the libgraph Elixir
      library).

  If the `:libgraph` algorithm is selected, these options are also available:

    `:find` - either `:shortest` (the default; to return a list with
      zero or one route), or `:all` (to return all possible routes).
    `:write_dot` - a boolean flag (default `false`). If `true`, a `.dot`
      file describing the graph for the route specification is written
      to the project's top-level directory.
  """
  def fetch_routes_for_specification(route_specification, opts) do
    if Keyword.get(opts, :algorithm, :random) == :random do
      RandomRouteFinder.fetch_routes_for_specification(route_specification, opts)
    else
      LibgraphRouteFinder.fetch_routes_for_specification(route_specification, opts)
    end
  end
end
