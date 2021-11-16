# CargoShipping

From the famous cargo shipping example in Eric Evans' 2003 book,
"Domain-Driven Design: Tackling Complexity in the Heart of Software".

Leverages code and patterns from:

* https://github.com/citerus/dddsample-core - The original Java implementation.
* https://github.com/pcmarks/ddd_elixir_demo_stage1 - A "stage 1" implementation in Elixir.

## Installation

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create, migrate and seed your database with `mix do ecto.reset, run priv/repo/seeds.exs`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

## Central concepts and patterns

1. Bounded contexts, like "CargoBookings" are implmented as Phoenix contexts.

2. Aggregates and entities are implemented as Ecto Schemas, and their states
  are saved in the PostgreSQL database.

3. Value objects are implemented as embbeded schemas within the aggregates.

4. Domain events are published using the
  [EventBus](https://github.com/otobus/event_bus) library.

5. Domain events are consumed asynchronously to update aggregates. Three
  different event handlers are implemented as GenServers in the
  `ApplicationEvents` namespace. A generic `Forwarder` event handler
  is also used to subscribe to events in order to post notifications to
  Phoenix LiveView processes to update the web interface.

## Module architecture

1. The project uses Sasa Juric's [boundary](https://github.com/sasa1977/boundary)
  library to enforce interface and core layers. The main layers are:
   * `CargoShippingWeb`, which depends on:
   * `CargoShipping`, which depends on:
   * `CargoShippingSchemas`, which defines value object and entity schemas.

2. The project uses Phoenix contexts (`CargoBookings`, `Reports`, and `VoyagePlans`)
  to contain core operations within Bounded Contexts.

3. The project uses Service modules (based on the dddsample) to coordinate
  complex operations.

## Services

Two new services, `LocationService` and `VoyageService`, were added to
the original list of services from the original dddsample Java application.

### LocationService

For performance reasons, a small subset of the UN "locodes" are maintained
in memory rather than in the PostgreSQL database. Read-only queries of location
data are accessed via the `LocationService` module.

### VoyageService

Similarly, since there are a small number of voyages in the sample code,
an in-memory cache is maintained of all voyage data. Any modification of
voyage data in the database causes a reload of all voyages into the cache.
Queries of voyage data access the cache via the `VoyageService` module.

### CargoBookingService

* book_new_cargo
* request_possible_routes_for_cargo
* assign_cargo_to_route
* change_destination

### CargoInspectionService

* inspect_cargo

### HandlingReportService

* submit_report

### HandlingEventService

* register_handling_event
* create_handling_event (added for testing)

### RoutingService

* fetch_routes_for_specification

### GraphTraversalService

* find_shortest_path
* find_all_paths (added)

## Itineraries

To better process unexpected handling events and maintain invariants, the schema for
the `Leg` objects which compose the `Itinerary` value object has been extended from
the original Java application to include the "actual" load and unload locations,
and to include the current state of the leg (not started, completed, in transit, etc.).

## Route finding implementation

The original Java implementation used a stub algorithm that generated random
itineraries to re-route cargos. For a better implementation, this application
uses the [libgraph](https://github.com/bitwalker/libgraph) Elixir library to search
the space of all available voyages to find the shortest sequence of voyage segments
for re-routing.


## Web interface

The web interface, implemented using Phoenix LiveView, is based on the
the original Java templates at

https://github.com/citerus/dddsample-core/tree/master/src/main/resources/templates

There are three Phoenix router scopes in the web application:

### Shipping clerks web interface at /clerks

* `get "/", PageController, :clerks` (clerks landing page)
* `live "/tracking", CargoLive.Search, :index` (from track.html, to get information on
  an existing cargo booking)

### Operation managers web interface at /managers

* `get "/", PageController, :managers` (managers landing page)
* `live "/cargos", CargoLive.Index, :index` (from admin/list.html, to list all available
  cargo bookings)
* `live "/cargos/new", CargoLive.New, :new` (from admin/registrationForm.html, to create
  a new cargo booking)
* `live "/cargos/id/:tracking_id", CargoLive.Show, :show` (from admin/show.html, to show detailed
  information on a cargo booking)
* `live "/cargos/id/:tracking_id/destination/edit", CargoLive.EditDestination, :edit` (from
  admin/pickNewDestination.html, to change the final destination for a cargo booking)
* `live "/cargos/id/:tracking_id/route/edit", CargoLive.EditRoute, :edit` (from
  admin/selectItinerary.html, to re-route a cargo booking)
* `live "/voyages", VoyageLive.Search, :index` (to list all voyages or voyages by ports)
* `live "/voyages/new", VoyageLive.New, :new` (to create a new voyage)
* `live "/voyages/number/:voyage_number", VoyageLive.Show, :show` (to show information on
  a voyage)
* `live "/events", HandlingEventLive.Index, :all` (to list all recent handling events)
* `live "/events/id/:tracking_id", HandlingEventLive.Index, :index` (to
  list handling events for a cargo booking)
* `live "/reports/new", HandlingReportLive.New, :new` (to file a cargo handling
  report directly)

### Handling Report REST API web interface at /api

* `resources "/handling_reports", HandlingReportController` (to create a handling report
  via an HTTP POST request)

## Testing

The test at `cargo_lifecycle_scenario_test.exs` is closely based on the
[CargoLifecycleScenarioTest.java](https://github.com/citerus/dddsample-core/blob/master/src/test/java/se/citerus/dddsample/scenario/CargoLifecycleScenarioTest.java)
in the original Java implementation.

## TODO

* Add a search page for voyages

* Apply all handling history events to a cargo (route specification + virgin itinerary).
  To do this, we will probably need to save the cargo's original route specification
  in the aggregate, and create new domain event topic(s) for route specification and/or
  itinerary changes.
