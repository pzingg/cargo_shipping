# CargoShipping

From the famous cargo shipping example in Eric Evans' 2003 book,
"Domain-Driven Design: Tackling Complexity in the Heart of Software".

Leverages code and patterns from:

* https://github.com/citerus/dddsample-core - The original Java implementation.
* https://github.com/pcmarks/ddd_elixir_demo_stage1 - A "stage 1" implementation in Elixir.

Central concepts and patterns:

1. Bounded contexts, like "CargoBookings" are implmented as Phoenix contexts.
2. Aggregates are implemented as Ecto Schemas, and their states are saved in the PostgreSQL database.
3. Value objects are implemented as embbeded schemas within the aggregates.
4. Domain events are published using the [EventBus](https://github.com/otobus/event_bus) library.
5. Domain events are consumed asynchronously and can update aggregates.


## Route finding implementation

The original Java implementation used a stub algorithm to re-route cargos. This implementation
uses the [libgraph](https://github.com/bitwalker/libgraph) Elixir library to search
the space of all available voyages to find the shortest sequence of voyage segments
for re-routing.


## Installation

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


## Web interface

The web interface, implemented using Phoenix LiveView, is based on the
the original Java templates at

https://github.com/citerus/dddsample-core/tree/master/src/main/resources/templates

There are three Phoenix router scopes in the web application:

### Shipping clerk web interface at /tracking

* `live "/", CargoLive.Search, :index` (from track.html, to get information on
  an existing cargo booking)
* `live "/reports/new", HandlingReportLive.Edit, :new` (to file a cargo handling
  report directly)
* `live "/events/:tracking_id", HandlingEventLive.Index, :index` (to
  list handling events for a cargo booking)

### Operation manager web interface at /managers

Implemented:

* `live "/", CargoLive.Index, :index` (from admin/list.html, to list all available
  cargo bookings)
* `live "/:id", CargoLive.Show, :show` (from admin/show.html, to show detailed
  information on a cargo booking)
* `live "/:id/destination/edit", CargoLive.EditDestination, :edit` (from
  admin/pickNewDestination.html, to change the final destination for a cargo booking)
* `live "/:id/route/edit", CargoLive.EditRoute, :edit` (from
  admin/selectItinerary.html, to re-route a cargo booking)

TODO:

* `live "/new", CargoLive.Index, :new` (from admin/registrationForm.html, to create
  a new cargo)
* `live "/events", HandlingEventLive.Index, :all` (to
  list handling events for all cargos)
* `live "/events/:tracking_id", HandlingEventLive.Index, :index` (to
  list handling events for a specific cargo booking)

### Handling Report REST API web interface at /api

* `resources "/handling_reports", HandlingReportController` (to create a handling report
  via an HTTP POST request)


## Testing

The test at `cargo_lifecycle_scenario_test.exs` is closely based on the
[CargoLifecycleScenarioTest.java](https://github.com/citerus/dddsample-core/blob/master/src/test/java/se/citerus/dddsample/scenario/CargoLifecycleScenarioTest.java)
in the original Java implementation.