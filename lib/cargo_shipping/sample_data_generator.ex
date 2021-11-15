defmodule CargoShipping.SampleDataGenerator do
  @moduledoc """
  Seeds the database.
  """
  require Logger

  alias CargoShipping.{CargoBookings, CargoBookingService, HandlingEventService, VoyagePlans}
  alias CargoShipping.CargoBookings.Itinerary
  alias CargoShipping.VoyagePlans.VoyageBuilder

  @base_time DateTime.utc_now() |> Timex.beginning_of_day() |> Timex.to_datetime()

  ## Sample data

  def voyage_0101() do
    # Voyage 0101: SESTO - FIHEL - DEHAM - CNHKG - JPTYO - AUMEL
    VoyageBuilder.init("0101", "SESTO")
    |> VoyageBuilder.add_destination("FIHEL", ts(1), ts(2))
    |> VoyageBuilder.add_destination("DEHAM", ts(1), ts(2))
    |> VoyageBuilder.add_destination("CNHKG", ts(1), ts(2))
    |> VoyageBuilder.add_destination("JPTYO", ts(1), ts(2))
    |> VoyageBuilder.add_destination("AUMEL", ts(1), ts(2))
    |> VoyageBuilder.build()
  end

  def voyage_0202() do
    # Voyage 0202: AUMEL - USCHI - DEHAM - SESTO - FIHEL
    VoyageBuilder.init("0202", "AUMEL")
    |> VoyageBuilder.add_destination("USCHI", ts(1), ts(2))
    |> VoyageBuilder.add_destination("DEHAM", ts(1), ts(2))
    |> VoyageBuilder.add_destination("SESTO", ts(1), ts(2))
    |> VoyageBuilder.add_destination("FIHEL", ts(1), ts(2))
    |> VoyageBuilder.build()
  end

  def voyage_0303() do
    # Voyage 0303: CNHKG - AUMEL - FIHEL - DEHAM - SESTO - USCHI - JPTYO
    VoyageBuilder.init("0303", "CNHKG")
    |> VoyageBuilder.add_destination("AUMEL", ts(1), ts(2))
    |> VoyageBuilder.add_destination("FIHEL", ts(1), ts(2))
    |> VoyageBuilder.add_destination("DEHAM", ts(1), ts(2))
    |> VoyageBuilder.add_destination("SESTO", ts(1), ts(2))
    |> VoyageBuilder.add_destination("USCHI", ts(1), ts(2))
    |> VoyageBuilder.add_destination("JPTYO", ts(1), ts(2))
    |> VoyageBuilder.build()
  end

  def itinerary_fgh(voyages) do
    # Cargo FGH: CNHKG - AUMEL - SESTO - FIHEL
    %{
      legs: [
        %{
          voyage_id: voyage_id_for(voyages, :voyage_0303),
          load_location: "CNHKG",
          unload_location: "AUMEL",
          load_time: ts(1),
          unload_time: ts(2),
          status: :NOT_LOADED
        },
        %{
          voyage_id: voyage_id_for(voyages, :voyage_0202),
          load_location: "AUMEL",
          unload_location: "SESTO",
          load_time: ts(3),
          unload_time: ts(4),
          status: :NOT_LOADED
        },
        %{
          voyage_id: voyage_id_for(voyages, :voyage_0202),
          load_location: "SESTO",
          unload_location: "FIHEL",
          load_time: ts(4),
          unload_time: ts(5),
          status: :NOT_LOADED
        }
      ]
    }
  end

  def legs_from_voyage(voyages, voyage_key) do
    voyage_for(voyages, voyage_key)
    |> Itinerary.legs_from_voyage()
  end

  @doc """
  Returns a map of voyages with keys :voyage_0101, etc.
  """
  def load_carrier_movement_data() do
    Enum.reduce(
      [
        :voyage_0101,
        :voyage_0202,
        :voyage_0303
      ],
      %{},
      fn func, acc ->
        attrs = apply(__MODULE__, func, [])
        {:ok, voyage} = VoyagePlans.create_voyage(attrs)
        Map.put(acc, func, voyage)
      end
    )
  end

  def load_cargo_data(voyages) do
    # Cargo XYZ: SESTO - FIHEL - DEHAM - CNHKG - JPTYO - AUMEL
    {:ok, cargo_xyz} =
      %{
        tracking_id: "XYZ",
        origin: "SESTO",
        route_specification: %{
          origin: "SESTO",
          destination: "AUMEL",
          earliest_departure: ts(0),
          arrival_deadline: ts(10)
        },
        itinerary: %{
          legs: legs_from_voyage(voyages, :voyage_0101)
        }
      }
      |> CargoBookingService.create_cargo()

    # Cargo ABC: AUMEL - FIHEL - DEHAM - SESTO - USCHI - JPTYO
    {:ok, cargo_abc} =
      %{
        tracking_id: "ABC",
        origin: "SESTO",
        route_specification: %{
          origin: "SESTO",
          destination: "FIHEL",
          earliest_departure: ts(0),
          arrival_deadline: ts(20)
        },
        itinerary: %{
          legs: legs_from_voyage(voyages, :voyage_0303) |> Enum.drop(1)
        }
      }
      |> CargoBookingService.create_cargo()

    # Cargo ZYX: AUMEL - USCHI - DEHAM - SESTO
    {:ok, cargo_zyx} =
      %{
        tracking_id: "ZYX",
        origin: "AUMEL",
        route_specification: %{
          origin: "AUMEL",
          destination: "SESTO",
          earliest_departure: ts(0),
          arrival_deadline: ts(30)
        },
        itinerary: %{
          legs: legs_from_voyage(voyages, :voyage_0202) |> Enum.take(3)
        }
      }
      |> CargoBookingService.create_cargo()

    # Cargo CBA: AUMEL - USCHI - DEHAM - SESTO
    # Cargo is MISROUTED!
    {:ok, cargo_cba} =
      %{
        tracking_id: "CBA",
        origin: "FIHEL",
        route_specification: %{
          origin: "FIHEL",
          destination: "USCHI",
          earliest_departure: ts(0),
          arrival_deadline: ts(40)
        },
        itinerary: %{
          legs: legs_from_voyage(voyages, :voyage_0303) |> Enum.take(4)
        }
      }
      |> CargoBookingService.create_cargo()

    :MISROUTED = cargo_cba.delivery.routing_status

    # Cargo FGH: CNHKG - AUMEL - SESTO - FIHEL
    # Cargo origin differs from spec origin?
    {:ok, cargo_fgh} =
      %{
        tracking_id: "FGH",
        origin: "SESTO",
        route_specification: %{
          origin: "CNHKG",
          destination: "FIHEL",
          earliest_departure: ts(0),
          arrival_deadline: ts(50)
        },
        itinerary: itinerary_fgh(voyages)
      }
      |> CargoBookingService.create_cargo()

    # Cargo JKL: DEHAM - SESTO - USCHI - JPTYO
    {:ok, cargo_jkl} =
      %{
        tracking_id: "JKL",
        origin: "DEHAM",
        route_specification: %{
          origin: "DEHAM",
          destination: "JPTYO",
          earliest_departure: ts(0),
          arrival_deadline: ts(60)
        },
        itinerary: %{
          legs: legs_from_voyage(voyages, :voyage_0303) |> Enum.drop(3)
        }
      }
      |> CargoBookingService.create_cargo()

    %{
      cargo_xyz: cargo_xyz,
      cargo_abc: cargo_abc,
      cargo_zyx: cargo_zyx,
      cargo_cba: cargo_cba,
      cargo_fgh: cargo_fgh,
      cargo_jkl: cargo_jkl
    }
  end

  def load_handling_event_data(voyages, cargos) do
    [
      # Cargo XYZ: SESTO - FIHEL - DEHAM - CNHKG - JPTYO - AUMEL
      {ts(0), ts(0), "RECEIVE", "SESTO", nil, :cargo_xyz},
      {ts(4), ts(5), "LOAD", "SESTO", :voyage_0101, :cargo_xyz},
      {ts(14), ts(14), "UNLOAD", "FIHEL", :voyage_0101, :cargo_xyz},
      {ts(15), ts(15), "LOAD", "FIHEL", :voyage_0101, :cargo_xyz},
      {ts(30), ts(30), "UNLOAD", "DEHAM", :voyage_0101, :cargo_xyz},
      {ts(33), ts(33), "LOAD", "DEHAM", :voyage_0101, :cargo_xyz},
      {ts(34), ts(34), "UNLOAD", "CNHKG", :voyage_0101, :cargo_xyz},
      {ts(60), ts(60), "LOAD", "CNHKG", :voyage_0101, :cargo_xyz},
      {ts(70), ts(71), "UNLOAD", "JPTYO", :voyage_0101, :cargo_xyz},
      {ts(75), ts(75), "LOAD", "JPTYO", :voyage_0101, :cargo_xyz},
      {ts(88), ts(88), "UNLOAD", "AUMEL", :voyage_0101, :cargo_xyz},
      {ts(100), ts(102), "CLAIM", "AUMEL", nil, :cargo_xyz},

      # Cargo ZYX: AUMEL - USCHI - DEHAM - SESTO
      {ts(200), ts(201), "RECEIVE", "AUMEL", nil, :cargo_zyx},
      {ts(202), ts(202), "LOAD", "AUMEL", :voyage_0202, :cargo_zyx},
      {ts(208), ts(208), "UNLOAD", "USCHI", :voyage_0202, :cargo_zyx},
      {ts(212), ts(212), "LOAD", "USCHI", :voyage_0202, :cargo_zyx},
      {ts(230), ts(230), "UNLOAD", "DEHAM", :voyage_0202, :cargo_zyx},
      {ts(235), ts(235), "LOAD", "DEHAM", :voyage_0202, :cargo_zyx},

      # Cargo ABC: AUMEL - FIHEL - DEHAM - SESTO - USCHI - JPTYO
      # Unpermitted event - emits cargo_handling_rejected event
      {ts(20), ts(21), "CLAIM", "AUMEL", nil, :cargo_abc},

      # Cargo CBA: AUMEL - USCHI - DEHAM - SESTO - FIHEL
      {ts(0), ts(1), "RECEIVE", "AUMEL", nil, :cargo_cba},
      {ts(10), ts(11), "LOAD", "AUMEL", :voyage_0202, :cargo_cba},
      {ts(20), ts(21), "UNLOAD", "USCHI", :voyage_0202, :cargo_cba},

      # Cargo FGH: CNHKG - AUMEL - SESTO - FIHEL
      {ts(100), ts(160), "RECEIVE", "CNHKG", nil, :cargo_fgh},
      {ts(150), ts(110), "LOAD", "CNHKG", :voyage_0303, :cargo_fgh},

      # Cargo JKL: DEHAM - SESTO - USCHI - JPTYO
      {ts(200), ts(220), "RECEIVE", "DEHAM", nil, :cargo_jkl},
      {ts(300), ts(330), "LOAD", "DEHAM", :voyage_0303, :cargo_jkl},
      # Unexpected event - cargo transport misdirected after this event
      {ts(400), ts(440), "UNLOAD", "FIHEL", :voyage_0303, :cargo_jkl}
    ]
    |> Enum.map(fn row -> insert_handling_event(voyages, cargos, row) end)
  end

  defp insert_handling_event(
         voyages,
         cargos,
         {completed_at, registered_at, event_type, location, voyage_name, cargo_name}
       ) do
    cargo = Map.fetch!(cargos, cargo_name)

    attrs = %{
      event_type: event_type,
      voyage_id: voyage_id_for(voyages, voyage_name),
      location: location,
      completed_at: completed_at,
      registered_at: registered_at
    }

    HandlingEventService.create_handling_event(cargo, attrs)
    wait_for_events()
  end

  def load_sample_data() do
    Logger.info("SampleDataGenerator.load_sample_data")

    # Locations are read-only in memory

    voyages = load_carrier_movement_data()
    cargos = load_cargo_data(voyages)
    load_handling_event_data(voyages, cargos)
    :ok
  end

  ## Hibernate data

  def load_cargo_abc123(voyages) do
    # Cargo ABC123

    attrs = %{
      tracking_id: "ABC123",
      route_specification: %{
        origin: "CNHKG",
        destination: "FIHEL",
        earliest_departure: ~U[2009-02-01 00:00:00Z],
        arrival_deadline: ~U[2009-03-15 00:00:00Z]
      },
      itinerary: %{
        legs: cargo_abc123_legs(voyages)
      }
    }

    {:ok, cargo_abc123} = CargoBookingService.create_cargo(attrs)
    wait_for_events()
    cargo_id = cargo_abc123.id

    attrs = %{
      event_type: "RECEIVE",
      voyage_id: nil,
      location: "CNHKG",
      completed_at: ~U[2009-03-01 00:00:00Z]
    }

    {:ok, _event1} = HandlingEventService.create_handling_event(cargo_abc123, attrs)
    wait_for_events()
    cargo_abc123 = CargoBookings.get_cargo!(cargo_id)

    attrs = %{
      event_type: "LOAD",
      voyage_id: voyage_id_for(voyages, :voyage_cnhkg_usnyc),
      location: "CNHKG",
      completed_at: ~U[2009-03-02 00:00:00Z]
    }

    {:ok, _event2} = HandlingEventService.create_handling_event(cargo_abc123, attrs)
    wait_for_events()
    cargo_abc123 = CargoBookings.get_cargo!(cargo_id)

    attrs = %{
      event_type: "UNLOAD",
      voyage_id: voyage_id_for(voyages, :voyage_cnhkg_usnyc),
      location: "USNYC",
      completed_at: ~U[2009-03-05 00:00:00Z]
    }

    {:ok, _event3} = HandlingEventService.create_handling_event(cargo_abc123, attrs)
    wait_for_events()

    # Note: create_handling_event will automatically derive the delivery.
    # We don't need the following:
    # cargo_abc123 = CargoBookings.get_cargo!(cargo_id)
    # handling_history = CargoBookings.lookup_handling_history(cargo_abc123.tracking_id)
    # params = CargoBookings.derive_delivery_progress(cargo_abc123, handling_history)
    # CargoBookings.update_cargo(cargo_abc123, params)
    # wait_for_events()
  end

  def cargo_abc123_legs(voyages) do
    [
      %{
        voyage_id: voyage_id_for(voyages, :voyage_cnhkg_usnyc),
        load_location: "CNHKG",
        unload_location: "USNYC",
        load_time: ~U[2009-03-02 00:00:00Z],
        unload_time: ~U[2009-03-05 00:00:00Z],
        status: :NOT_LOADED
      },
      %{
        voyage_id: voyage_id_for(voyages, :voyage_usnyc_usdal),
        load_location: "USNYC",
        unload_location: "USDAL",
        load_time: ~U[2009-03-06 00:00:00Z],
        unload_time: ~U[2009-03-08 00:00:00Z],
        status: :NOT_LOADED
      },
      %{
        voyage_id: voyage_id_for(voyages, :voyage_usdal_fihel),
        load_location: "USDAL",
        unload_location: "FIHEL",
        load_time: ~U[2009-03-09 00:00:00Z],
        unload_time: ~U[2009-03-12 00:00:00Z],
        status: :NOT_LOADED
      }
    ]
  end

  def load_cargo_jkl567(voyages) do
    # Cargo JKL567

    attrs = %{
      tracking_id: "JKL567",
      route_specification: %{
        origin: "CNHGH",
        destination: "SESTO",
        earliest_departure: ~U[2009-02-01 00:00:00Z],
        arrival_deadline: ~U[2009-03-18 00:00:00Z]
      },
      itinerary: %{
        legs: cargo_jkl567_legs(voyages)
      }
    }

    {:ok, cargo_jkl567} = CargoBookingService.create_cargo(attrs)
    wait_for_events()
    cargo_id = cargo_jkl567.id

    attrs = %{
      event_type: "RECEIVE",
      voyage_id: nil,
      location: "CNHGH",
      completed_at: ~U[2009-03-01 00:00:00Z]
    }

    {:ok, _event1} = HandlingEventService.create_handling_event(cargo_jkl567, attrs)
    wait_for_events()
    cargo_jkl567 = CargoBookings.get_cargo!(cargo_id)

    attrs = %{
      event_type: "LOAD",
      voyage_id: voyage_id_for(voyages, :voyage_cnhkg_usnyc),
      location: "CNHGH",
      completed_at: ~U[2009-03-03 00:00:00Z]
    }

    {:ok, _event2} = HandlingEventService.create_handling_event(cargo_jkl567, attrs)
    wait_for_events()
    cargo_jkl567 = CargoBookings.get_cargo!(cargo_id)

    attrs = %{
      event_type: "UNLOAD",
      voyage_id: voyage_id_for(voyages, :voyage_cnhkg_usnyc),
      location: "USNYC",
      completed_at: ~U[2009-03-05 00:00:00Z]
    }

    {:ok, _event3} = HandlingEventService.create_handling_event(cargo_jkl567, attrs)
    wait_for_events()
    cargo_jkl567 = CargoBookings.get_cargo!(cargo_id)

    attrs = %{
      event_type: "LOAD",
      voyage_id: voyage_id_for(voyages, :voyage_usnyc_usdal),
      location: "USNYC",
      completed_at: ~U[2009-03-06 00:00:00Z]
    }

    {:ok, _event4} = HandlingEventService.create_handling_event(cargo_jkl567, attrs)
    wait_for_events()

    # Note: create_handling_event will automatically derive the delivery.
    # We don't need the following:
    # cargo_jkl567 = CargoBookings.get_cargo!(cargo_id)
    # handling_history = CargoBookings.lookup_handling_history(cargo_jkl567.tracking_id)
    # params = CargoBookings.derive_delivery_progress(cargo_jkl567, handling_history)
    # CargoBookings.update_cargo(cargo_jkl567, params)
    # wait_for_events()
  end

  def cargo_jkl567_legs(voyages) do
    [
      %{
        voyage_id: voyage_id_for(voyages, :voyage_cnhkg_usnyc),
        load_location: "CNHGH",
        unload_location: "USNYC",
        load_time: ~U[2009-03-03 00:00:00Z],
        unload_time: ~U[2009-03-05 00:00:00Z],
        status: :NOT_LOADED
      },
      %{
        voyage_id: voyage_id_for(voyages, :voyage_usnyc_usdal),
        load_location: "USNYC",
        unload_location: "USDAL",
        load_time: ~U[2009-03-06 00:00:00Z],
        unload_time: ~U[2009-03-08 00:00:00Z],
        status: :NOT_LOADED
      },
      %{
        voyage_id: voyage_id_for(voyages, :voyage_usdal_fihel),
        load_location: "USDAL",
        unload_location: "SESTO",
        load_time: ~U[2009-03-09 00:00:00Z],
        unload_time: ~U[2009-03-11 00:00:00Z],
        status: :NOT_LOADED
      }
    ]
  end

  ## Sample voyages

  def voyage_v100() do
    VoyageBuilder.init("V100", "CNHKG")
    |> VoyageBuilder.add_destination(
      "JPTYO",
      ~U[2009-03-03 00:00:00Z],
      ~U[2009-03-06 00:00:00Z]
    )
    |> VoyageBuilder.add_destination(
      "USNYC",
      ~U[2009-03-06 00:00:00Z],
      ~U[2009-03-09 00:00:00Z]
    )
    |> VoyageBuilder.build()
  end

  def voyage_v200() do
    VoyageBuilder.init("V200", "JPTYO")
    |> VoyageBuilder.add_destination(
      "USNYC",
      ~U[2009-03-06 00:00:00Z],
      ~U[2009-03-08 00:00:00Z]
    )
    |> VoyageBuilder.add_destination(
      "USCHI",
      ~U[2009-03-10 00:00:00Z],
      ~U[2009-03-14 00:00:00Z]
    )
    |> VoyageBuilder.add_destination(
      "SESTO",
      ~U[2009-03-14 00:00:00Z],
      ~U[2009-03-16 00:00:00Z]
    )
    |> VoyageBuilder.build()
  end

  def voyage_v300() do
    VoyageBuilder.init("V300", "JPTYO")
    |> VoyageBuilder.add_destination(
      "NLRTM",
      ~U[2009-03-08 00:00:00Z],
      ~U[2009-03-11 00:00:00Z]
    )
    |> VoyageBuilder.add_destination(
      "DEHAM",
      ~U[2009-03-11 00:00:00Z],
      ~U[2009-03-12 00:00:00Z]
    )
    |> VoyageBuilder.add_destination(
      "AUMEL",
      ~U[2009-03-14 00:00:00Z],
      ~U[2009-03-18 00:00:00Z]
    )
    |> VoyageBuilder.add_destination(
      "JPTYO",
      ~U[2009-03-19 00:00:00Z],
      ~U[2009-03-21 00:00:00Z]
    )
    |> VoyageBuilder.build()
  end

  def voyage_v400() do
    VoyageBuilder.init("V400", "DEHAM")
    |> VoyageBuilder.add_destination(
      "SESTO",
      ~U[2009-03-14 00:00:00Z],
      ~U[2009-03-15 00:00:00Z]
    )
    |> VoyageBuilder.add_destination(
      "FIHEL",
      ~U[2009-03-15 00:00:00Z],
      ~U[2009-03-16 00:00:00Z]
    )
    |> VoyageBuilder.add_destination(
      "DEHAM",
      ~U[2009-03-20 00:00:00Z],
      ~U[2009-03-22 00:00:00Z]
    )
    |> VoyageBuilder.build()
  end

  def voyage_cnhkg_usnyc() do
    # Voyage number 0100S (by ship)
    # Hongkong - Hangzou - Tokyo - Melbourne - New York
    VoyageBuilder.init("0100S", "CNHKG")
    |> VoyageBuilder.add_destination(
      "CNHGH",
      ~U[2008-10-01 12:00:00Z],
      ~U[2008-10-03 14:30:00Z]
    )
    |> VoyageBuilder.add_destination(
      "JPTYO",
      ~U[2008-10-03 21:00:00Z],
      ~U[2008-10-06 06:15:00Z]
    )
    |> VoyageBuilder.add_destination(
      "AUMEL",
      ~U[2008-10-06 11:00:00Z],
      ~U[2008-10-12 11:30:00Z]
    )
    |> VoyageBuilder.add_destination(
      "USNYC",
      ~U[2008-10-13 12:00:00Z],
      ~U[2008-10-14 23:10:00Z]
    )
    |> VoyageBuilder.build()
  end

  ## From SampleVoyages.java

  def voyage_usnyc_usdal() do
    # Voyage number 0200T (by train)
    # New York - Chicago - Dallas
    VoyageBuilder.init("0200T", "USNYC")
    |> VoyageBuilder.add_destination(
      "USCHI",
      ~U[2008-10-24 07:00:00Z],
      ~U[2008-10-24 17:45:00Z]
    )
    |> VoyageBuilder.add_destination(
      "USDAL",
      ~U[2008-10-24 21:25:00Z],
      ~U[2008-10-25 19:30:00Z]
    )
    |> VoyageBuilder.build()
  end

  def voyage_usdal_fihel() do
    # Voyage number 0300A (by airplane)
    # Dallas - Hamburg - Stockholm - Helsinki
    VoyageBuilder.init("0300A", "USDAL")
    |> VoyageBuilder.add_destination(
      "DEHAM",
      ~U[2008-10-29 03:30:00Z],
      ~U[2008-10-31 14:00:00Z]
    )
    |> VoyageBuilder.add_destination(
      "SESTO",
      ~U[2008-11-01 15:20:00Z],
      ~U[2008-11-01 18:40:00Z]
    )
    |> VoyageBuilder.add_destination(
      "FIHEL",
      ~U[2008-11-02 09:00:00Z],
      ~U[2008-11-02 11:15:00Z]
    )
    |> VoyageBuilder.build()
  end

  def voyage_usdal_fihel_alt() do
    # Voyage number 0301S (by ship)
    # Dallas - Hamburg - Stockholm - Helsinki, alternate route
    VoyageBuilder.init("0301S", "USDAL")
    |> VoyageBuilder.add_destination(
      "FIHEL",
      ~U[2008-10-29 03:30:00Z],
      ~U[2008-11-05 15:45:00Z]
    )
    |> VoyageBuilder.build()
  end

  def voyage_fihel_cnhkg() do
    # Voyage number 0400S (by ship)
    # Helsinki - Rotterdam - Shanghai - Hongkong
    VoyageBuilder.init("0400S", "FIHEL")
    |> VoyageBuilder.add_destination(
      "NLRTM",
      ~U[2008-11-04 05:50:00Z],
      ~U[2008-11-06 14:10:00Z]
    )
    |> VoyageBuilder.add_destination(
      "CNSHA",
      ~U[2008-11-10 21:45:00Z],
      ~U[2008-11-22 16:40:00Z]
    )
    |> VoyageBuilder.add_destination(
      "CNHKG",
      ~U[2008-11-24 07:00:00Z],
      ~U[2008-11-28 13:37:00Z]
    )
    |> VoyageBuilder.build()
  end

  def generate_voyages() do
    Enum.reduce(
      [
        :voyage_v100,
        :voyage_v200,
        :voyage_v300,
        :voyage_v400,
        :voyage_cnhkg_usnyc,
        :voyage_usnyc_usdal,
        :voyage_usdal_fihel,
        :voyage_usdal_fihel_alt,
        :voyage_fihel_cnhkg
      ],
      %{},
      fn func, acc ->
        attrs = apply(__MODULE__, func, [])
        {:ok, voyage} = VoyagePlans.create_voyage(attrs)
        Map.put(acc, func, voyage)
      end
    )
  end

  def generate_cargos(voyages) do
    load_cargo_abc123(voyages)
    load_cargo_jkl567(voyages)

    :ok
  end

  def generate() do
    Logger.info("SampleDataGenerator.generate")

    # Locations are read-only in memory

    voyages = generate_voyages()
    generate_cargos(voyages)
  end

  ## Utilities

  defp wait_for_events(), do: Process.sleep(100)

  defp ts(hours) do
    DateTime.add(@base_time, hours * 3600, :second)
  end

  defp voyage_for(voyages, key), do: Map.fetch!(voyages, key)

  defp voyage_id_for(_voyages, nil), do: nil

  defp voyage_id_for(voyages, key) do
    voyage_for(voyages, key) |> Map.fetch!(:id)
  end
end
