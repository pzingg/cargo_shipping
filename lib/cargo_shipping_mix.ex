defmodule CargoShippingMix do
  @moduledoc """
  The CargoShippingMix is the top-level boundary that contains all the
  code that is specific to custom mix tasks, which mostly revolve
  around setting up the database on local dev, and setting up CI.

  This is the only part of the code where runtime invocation of mix
  functions, such as `Mix.env()`, is permitted. Compile-time mix
  invocations are allowed everywhere.
  """
  use Boundary, deps: [Mix, CargoShippingApplication, CargoShipping], exports: []
end
