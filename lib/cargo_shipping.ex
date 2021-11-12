defmodule CargoShipping do
  @moduledoc """
  CargoShipping is the core business logic boundary.

  The core is the only boundary that is further divided into
  sub-boundaries, which are the bounded contexts that define our domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  use Boundary,
    deps: [Ecto, Ecto.Changeset, CargoShippingConfig, CargoShippingSchemas],
    exports: [
      # Bounded context modules
      CargoBookings,
      Locations,
      Reports,
      VoyagePlans,
      # Utilities
      SampleDataGenerator,
      Utils,
      # Sub-modules - these should probably NOT be exposed,
      CargoBookings.Cargo,
      CargoBookings.Delivery,
      CargoBookings.Itinerary,
      CargoBookings.RouteSpecification,
      # Service modules
      CargoBookingService,
      CargoInspectionService,
      HandlingEventService,
      HandlingReportService,
      LocationService,
      RoutingService,
      VoyageService
    ]
end
