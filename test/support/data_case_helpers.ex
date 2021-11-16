defmodule CargoShipping.DataCaseHelpers do
  @moduledoc """
  DRY functions used by DataCase, ConnCase and ChannelCase setup.
  """

  alias CargoShipping.Infra.Repo
  alias CargoShipping.SampleDataGenerator
  alias Ecto.Adapters.SQL.Sandbox
  alias ExUnit.Callbacks

  def start_sandbox_owner(tags) do
    pid = Sandbox.start_owner!(Repo, shared: not tags[:async])

    Callbacks.on_exit(fn -> Sandbox.stop_owner(pid) end)

    {:ok, pid}
  end

  def load_sample_data(tags) do
    if tags[:sample_data] do
      :ok = SampleDataGenerator.load_sample_data()
    end

    case Map.get(tags, :hibernate_data) do
      nil ->
        :ok

      :voyages ->
        _ = SampleDataGenerator.generate_voyages()
        :ok

      _ ->
        :ok = SampleDataGenerator.generate()
    end

    :ok
  end
end
