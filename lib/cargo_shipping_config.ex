defmodule CargoShippingConfig do
  @moduledoc """
  CargoShipping is a single-module, top-level boundary that
  consolidates what we call the operator config. These are the system
  parameters that have to be provided at the target machine
  (e.g. staging or release), such as the site’s public URL,
  database connection string, credentials to 3rd party services, etc.

  The config module wraps the access to those parameters. The client
  code invokes something like `CargoShippingConfig.database_url()`,
  and the value is fetched from some source, such as OS environment
  variables.
  """
  use Boundary, deps: [], exports: []
end
