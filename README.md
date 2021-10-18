# CargoShipping

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix


%{
  tracking_id: "ABC123",
  route_specification: %{
    arrival_deadline: ~U[2009-03-15 00:00:00Z],
    destination: "FIHEL",
    origin: "CNHKG"
  },
  itinerary: %{
    legs: [
      %{
        load_location: "CNHKG", load_time: ~U[2009-03-02 00:00:00Z],
        unload_location: "USNYC", unload_time: ~U[2009-03-05 00:00:00Z],
        voyage_id: "03a0f98f-31bb-4f1f-8181-bfe8df670232"
      },
      %{
        load_location: "USNYC", load_time: ~U[2009-03-06 00:00:00Z],
        unload_location: "USDAL", unload_time: ~U[2009-03-08 00:00:00Z],
        voyage_id: "bb0099b3-84cd-4413-aab3-110f19bbf651"
      },
      %{
        load_location: "USDAL", load_time: ~U[2009-03-09 00:00:00Z],
        unload_location: "FIHEL", unload_time: ~U[2009-03-12 00:00:00Z],
        voyage_id: "3543650b-f6e9-4da2-8af7-5d22e46e5a94"
      }
    ]
  },
  delivery: %{
    calculated_at: ~U[2021-10-18 17:13:49.521467Z],
    current_voyage_id: nil,
    eta: nil,
    unloaded_at_destination?: false,
    last_event_id: nil,
    last_known_location: "_",
    misdirected?: nil,
    next_expected_activity: nil,
    routing_status: :ROUTED,
    transport_status: :NOT_RECEIVED
  }
}

#Ecto.Changeset<action: :insert, changes: %{calculated_at: ~U[2021-10-18 18:37:49Z], last_known_location: "_", routing_status: :ROUTED}

  2) test hibernate data loads hibernate data (CargoShipping.LoadDataTest)
     test/cargo_shipping/load_data_test.exs:15
     ** (MatchError) no match of right hand side value: {:error, #Ecto.Changeset<action: :insert, changes: %{delivery: #Ecto.Changeset<action: :insert, changes: %{calculated_at: ~U[2021-10-18 15:58:56Z], routing_status: :ROUTED}, errors: [next_expected_activity: {"is invalid", [validation: :embed, type: :map]}, last_known_location: {"can't be blank", [validation: :required]}, misdirected?: {"can't be blank", [validation: :required]}, unloaded_at_destination?: {"can't be blank", [validation: :required]}, transport_status: {"is invalid", [type: {:parameterized, Ecto.Enum, %{mappings: [NOT_RECEIVED: "NOT_RECEIVED", IN_PORT: "IN_PORT", ONBOARD_CARRIER: "ONBOARD_CARRIER", CLAIMED: "CLAIMED", UNKNOWN: "UNKNOWN"], on_cast: %{"CLAIMED" => :CLAIMED, "IN_PORT" => :IN_PORT, "NOT_RECEIVED" => :NOT_RECEIVED, "ONBOARD_CARRIER" => :ONBOARD_CARRIER, "UNKNOWN" => :UNKNOWN}, on_dump: %{CLAIMED: "CLAIMED", IN_PORT: "IN_PORT", NOT_RECEIVED: "NOT_RECEIVED", ONBOARD_CARRIER: "ONBOARD_CARRIER", UNKNOWN: "UNKNOWN"}, on_load: %{"CLAIMED" => :CLAIMED, "IN_PORT" => :IN_PORT, "NOT_RECEIVED" => :NOT_RECEIVED, "ONBOARD_CARRIER" => :ONBOARD_CARRIER, "UNKNOWN" => :UNKNOWN}, type: :string}}, validation: :cast]}], data: #CargoShipping.CargoBookings.Delivery<>, valid?: false>, itinerary: #Ecto.Changeset<action: :insert, changes: %{legs: [#Ecto.Changeset<action: :insert, changes: %{load_location: "CNHKG", load_time: ~U[2009-03-02 00:00:00Z], unload_location: "USNYC", unload_time: ~U[2009-03-05 00:00:00Z], voyage_id: "b19bc77f-3c00-49d2-b5c3-c9896d81bfd7"}, errors: [], data: #CargoShipping.CargoBookings.Leg<>, valid?: true>, #Ecto.Changeset<action: :insert, changes: %{load_location: "USNYC", load_time: ~U[2009-03-06 00:00:00Z], unload_location: "USDAL", unload_time: ~U[2009-03-08 00:00:00Z], voyage_id: "b311f613-0c23-48e6-b8f4-12a095ae9acd"}, errors: [], data: #CargoShipping.CargoBookings.Leg<>, valid?: true>, #Ecto.Changeset<action: :insert, changes: %{load_location: "USDAL", load_time: ~U[2009-03-09 00:00:00Z], unload_location: "FIHEL", unload_time: ~U[2009-03-12 00:00:00Z], voyage_id: "af929ca5-b976-40b9-867d-44242652dfd7"}, errors: [], data: #CargoShipping.CargoBookings.Leg<>, valid?: true>]}, errors: [], data: #CargoShipping.CargoBookings.Itinerary<>, valid?: true>, route_specification: #Ecto.Changeset<action: :insert, changes: %{arrival_deadline: ~U[2009-03-15 00:00:00Z], destination: "FIHEL", origin: "CNHKG"}, errors: [], data: #CargoShipping.CargoBookings.RouteSpecification<>, valid?: true>, tracking_id: "ABC123"}, errors: [origin: {"can't be blank", [validation: :required]}], data: #CargoShipping.CargoBookings.Cargo<>, valid?: false>}
     stacktrace:
       (cargo_shipping 0.1.0) lib/cargo_shipping/sample_data_generator.ex:353: CargoShipping.SampleDataGenerator.load_cargo_abc123/1
       (cargo_shipping 0.1.0) lib/cargo_shipping/sample_data_generator.ex:628: CargoShipping.SampleDataGenerator.generate/0
       (cargo_shipping 0.1.0) test/support/data_case.ex:38: CargoShipping.DataCase.__ex_unit_setup_0/1
       (cargo_shipping 0.1.0) test/support/data_case.ex:1: CargoShipping.DataCase.__ex_unit__/2
       test/cargo_shipping/load_data_test.exs:1: CargoShipping.LoadDataTest.__ex_unit__/2


