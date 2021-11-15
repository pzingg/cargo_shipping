defmodule CargoShippingWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use CargoShippingWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import CargoShippingWeb.ConnCase

      alias CargoShippingWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint CargoShippingWeb.Endpoint
    end
  end

  setup tags do
    pid =
      Ecto.Adapters.SQL.Sandbox.start_owner!(CargoShipping.Infra.Repo, shared: not tags[:async])

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    if tags[:sample_data] do
      :ok = CargoShipping.SampleDataGenerator.load_sample_data()
    end

    case Map.get(tags, :hibernate_data) do
      nil ->
        :ok

      :voyages ->
        _ = CargoShipping.SampleDataGenerator.generate_voyages()
        :ok

      _ ->
        :ok = CargoShipping.SampleDataGenerator.generate()
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
