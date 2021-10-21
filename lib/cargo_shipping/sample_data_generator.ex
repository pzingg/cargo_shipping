defmodule CargoShipping.SampleDataGenerator do
  @moduledoc """
  Seeds the database.
  """
  alias CargoShipping.{CargoBookings, VoyagePlans}
  alias CargoShipping.VoyagePlans.VoyageBuilder

  @base_time DateTime.utc_now() |> Timex.beginning_of_day() |> Timex.to_datetime()

  ## Sample data

  def voyage_0101() do
    VoyageBuilder.init("0101", "SESTO")
    |> VoyageBuilder.add_movement("FIHEL", ts(1), ts(2))
    |> VoyageBuilder.add_movement("DEHAM", ts(1), ts(2))
    |> VoyageBuilder.add_movement("CNHKG", ts(1), ts(2))
    |> VoyageBuilder.add_movement("JPTOK", ts(1), ts(2))
    |> VoyageBuilder.add_movement("AUMEL", ts(1), ts(2))
    |> VoyageBuilder.build()
  end

  def voyage_0202() do
    VoyageBuilder.init("0202", "AUMEL")
    |> VoyageBuilder.add_movement("USCHI", ts(1), ts(2))
    |> VoyageBuilder.add_movement("DEHAM", ts(1), ts(2))
    |> VoyageBuilder.add_movement("SESTO", ts(1), ts(2))
    |> VoyageBuilder.add_movement("FIHEL", ts(1), ts(2))
    |> VoyageBuilder.build()
  end

  def voyage_0303() do
    VoyageBuilder.init("0303", "CNHKG")
    |> VoyageBuilder.add_movement("AUMEL", ts(1), ts(2))
    |> VoyageBuilder.add_movement("FIHEL", ts(1), ts(2))
    |> VoyageBuilder.add_movement("DEHAM", ts(1), ts(2))
    |> VoyageBuilder.add_movement("SESTO", ts(1), ts(2))
    |> VoyageBuilder.add_movement("USCHI", ts(1), ts(2))
    |> VoyageBuilder.add_movement("JPTOK", ts(1), ts(2))
    |> VoyageBuilder.build()
  end

  def legs_fgh(voyage_id) do
    # voyage_0101, Hongkong - Melbourne - Stockholm - Helsinki
    [
      %{
        voyage_id: voyage_id,
        load_location: "CNHKG",
        unload_location: "AUMEL",
        load_time: ts(1),
        unload_time: ts(2)
      },
      %{
        voyage_id: voyage_id,
        load_location: "AUMEL",
        unload_location: "SESTO",
        load_time: ts(3),
        unload_time: ts(4)
      },
      %{
        voyage_id: voyage_id,
        load_location: "SESTO",
        unload_location: "FIHEL",
        load_time: ts(4),
        unload_time: ts(5)
      }
    ]
  end

  def legs_jkl(voyage_id) do
    # voyage_0202, Hamburg - Stockholm - Chicago - Tokyo
    [
      %{
        voyage_id: voyage_id,
        load_location: "DEHAM",
        unload_location: "SESTO",
        load_time: ts(1),
        unload_time: ts(2)
      },
      %{
        voyage_id: voyage_id,
        load_location: "SESTO",
        unload_location: "USCHI",
        load_time: ts(3),
        unload_time: ts(4)
      },
      %{
        voyage_id: voyage_id,
        load_location: "USCHI",
        unload_location: "JPTOK",
        load_time: ts(5),
        unload_time: ts(6)
      }
    ]
  end

  def load_itinerary_data(voyages) do
    %{
      itinerary_fgh: %{
        legs: voyage_id_for(voyages, :voyage_0101) |> legs_fgh()
      },
      itinerary_jkl: %{
        legs: voyage_id_for(voyages, :voyage_0202) |> legs_jkl()
      }
    }
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

  def load_cargo_data(itineraries) do
    {:ok, cargo_xyz} =
      %{
        tracking_id: "XYZ",
        origin: "SESTO",
        route_specification: %{
          origin: "SESTO",
          destination: "AUMEL",
          arrival_deadline: ts(10)
        },
        delivery: %{
          transport_status: :IN_PORT,
          current_voyage_id: nil,
          last_known_location: "SESTO",
          misdirected?: false,
          routing_status: :ROUTED,
          calculated_at: ts(100),
          unloaded_at_destination?: false
        }
      }
      |> CargoBookings.create_cargo()

    {:ok, cargo_abc} =
      %{
        tracking_id: "ABC",
        origin: "SESTO",
        route_specification: %{
          origin: "SESTO",
          destination: "FIHEL",
          arrival_deadline: ts(20)
        },
        delivery: %{
          transport_status: :IN_PORT,
          current_voyage_id: nil,
          last_known_location: "SESTO",
          misdirected?: false,
          routing_status: :ROUTED,
          calculated_at: ts(100),
          unloaded_at_destination?: false
        }
      }
      |> CargoBookings.create_cargo()

    {:ok, cargo_zyx} =
      %{
        tracking_id: "ZYX",
        origin: "AUMEL",
        route_specification: %{
          origin: "AUMEL",
          destination: "SESTO",
          arrival_deadline: ts(30)
        },
        delivery: %{
          transport_status: :IN_PORT,
          current_voyage_id: nil,
          last_known_location: "SESTO",
          misdirected?: false,
          routing_status: :NOT_ROUTED,
          calculated_at: ts(100),
          unloaded_at_destination?: false
        }
      }
      |> CargoBookings.create_cargo()

    {:ok, cargo_cba} =
      %{
        tracking_id: "CBA",
        origin: "FIHEL",
        route_specification: %{
          origin: "FIHEL",
          destination: "SESTO",
          arrival_deadline: ts(40)
        },
        delivery: %{
          transport_status: :IN_PORT,
          current_voyage_id: nil,
          last_known_location: "SESTO",
          misdirected?: false,
          routing_status: :MISROUTED,
          calculated_at: ts(100),
          unloaded_at_destination?: false
        }
      }
      |> CargoBookings.create_cargo()

    # Cargo origin differs from spec origin
    {:ok, cargo_fgh} =
      %{
        tracking_id: "FGH",
        origin: "SESTO",
        route_specification: %{
          origin: "CNHKG",
          destination: "FIHEL",
          arrival_deadline: ts(50)
        },
        itinerary: Map.fetch!(itineraries, :itinerary_fgh),
        delivery: %{
          transport_status: :IN_PORT,
          current_voyage_id: nil,
          last_known_location: "SESTO",
          misdirected?: false,
          routing_status: :ROUTED,
          calculated_at: ts(100),
          unloaded_at_destination?: false
        }
      }
      |> CargoBookings.create_cargo()

    {:ok, cargo_jkl} =
      %{
        tracking_id: "JKL",
        origin: "DEHAM",
        route_specification: %{
          origin: "DEHAM",
          destination: "JPTOK",
          arrival_deadline: ts(60)
        },
        itinerary: Map.fetch!(itineraries, :itinerary_jkl),
        delivery: %{
          transport_status: :IN_PORT,
          current_voyage_id: nil,
          last_known_location: "SESTO",
          misdirected?: false,
          routing_status: :ROUTED,
          calculated_at: ts(100),
          unloaded_at_destination?: false
        }
      }
      |> CargoBookings.create_cargo()

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
      # XYZ (SESTO - FIHEL - DEHAM - CNHKG - JPTOK - AUMEL)
      {ts(0), ts(0), "RECEIVE", "SESTO", nil, :cargo_xyz},
      {ts(4), ts(5), "LOAD", "SESTO", :voyage_0101, :cargo_xyz},
      {ts(14), ts(14), "UNLOAD", "FIHEL", :voyage_0101, :cargo_xyz},
      {ts(15), ts(15), "LOAD", "FIHEL", :voyage_0101, :cargo_xyz},
      {ts(30), ts(30), "UNLOAD", "DEHAM", :voyage_0101, :cargo_xyz},
      {ts(33), ts(33), "LOAD", "DEHAM", :voyage_0101, :cargo_xyz},
      {ts(34), ts(34), "UNLOAD", "CNHKG", :voyage_0101, :cargo_xyz},
      {ts(60), ts(60), "LOAD", "CNHKG", :voyage_0101, :cargo_xyz},
      {ts(70), ts(71), "UNLOAD", "JPTOK", :voyage_0101, :cargo_xyz},
      {ts(75), ts(75), "LOAD", "JPTOK", :voyage_0101, :cargo_xyz},
      {ts(88), ts(88), "UNLOAD", "AUMEL", :voyage_0101, :cargo_xyz},
      {ts(100), ts(102), "CLAIM", "AUMEL", nil, :cargo_xyz},

      # ZYX (AUMEL - USCHI - DEHAM)
      {ts(200), ts(201), "RECEIVE", "AUMEL", nil, :cargo_zyx},
      {ts(202), ts(202), "LOAD", "AUMEL", :voyage_0202, :cargo_zyx},
      {ts(208), ts(208), "UNLOAD", "USCHI", :voyage_0202, :cargo_zyx},
      {ts(212), ts(212), "LOAD", "USCHI", :voyage_0202, :cargo_zyx},
      {ts(230), ts(230), "UNLOAD", "DEHAM", :voyage_0202, :cargo_zyx},
      {ts(235), ts(235), "LOAD", "DEHAM", :voyage_0202, :cargo_zyx},

      # ABC
      {ts(20), ts(21), "CLAIM", "AUMEL", nil, :cargo_abc},

      # CBA
      {ts(0), ts(1), "RECEIVE", "AUMEL", nil, :cargo_cba},
      {ts(10), ts(11), "LOAD", "AUMEL", :voyage_0202, :cargo_cba},
      {ts(20), ts(21), "UNLOAD", "USCHI", :voyage_0202, :cargo_cba},

      # FGH
      {ts(100), ts(160), "RECEIVE", "CNHKG", nil, :cargo_fgh},
      {ts(150), ts(110), "LOAD", "CNHKG", :voyage_0303, :cargo_fgh},

      # JKL
      {ts(200), ts(220), "RECEIVE", "DEHAM", nil, :cargo_jkl},
      {ts(300), ts(330), "LOAD", "DEHAM", :voyage_0303, :cargo_jkl},
      # Unexpected event
      {ts(400), ts(440), "UNLOAD", "FIHEL", :voyage_0303, :cargo_jkl}
    ]
    |> Enum.map(fn {completed_at, registered_at, event_type, location, voyage_name, cargo_name} ->
      cargo = Map.fetch!(cargos, cargo_name)

      attrs = %{
        event_type: event_type,
        voyage_id: voyage_id_for(voyages, voyage_name),
        location: location,
        completed_at: completed_at,
        registered_at: registered_at
      }

      {:ok, _handling_event} = CargoBookings.create_handling_event(cargo, attrs)
    end)
  end

  def load_sample_data() do
    # Locations are read-only in memory

    voyages = load_carrier_movement_data()
    itineraries = load_itinerary_data(voyages)
    cargos = load_cargo_data(itineraries)
    load_handling_event_data(voyages, cargos)

    :ok
  end

  ## Hibernate data

  def load_cargo_abc123(voyages) do
    # Cargo ABC123

    itinerary = %{
      legs: cargo_abc123_legs(voyages)
    }

    attrs =
      %{
        tracking_id: "ABC123",
        route_specification: %{
          origin: "CNHKG",
          destination: "FIHEL",
          arrival_deadline: ~U[2009-03-15 00:00:00Z]
        }
      }
      |> CargoBookings.assign_cargo_to_route(itinerary)

    {:ok, cargo_abc123} = CargoBookings.create_cargo(attrs)

    attrs = %{
      event_type: "RECEIVE",
      voyage_id: nil,
      location: "CNHKG",
      completed_at: ~U[2009-03-01 00:00:00Z]
    }

    {:ok, _event1} = CargoBookings.create_handling_event(cargo_abc123, attrs)

    attrs = %{
      event_type: "LOAD",
      voyage_id: voyage_id_for(voyages, :voyage_cnhkg_usnyc),
      location: "CNHKG",
      completed_at: ~U[2009-03-02 00:00:00Z]
    }

    {:ok, _event2} = CargoBookings.create_handling_event(cargo_abc123, attrs)

    attrs = %{
      event_type: "UNLOAD",
      voyage_id: voyage_id_for(voyages, :voyage_cnhkg_usnyc),
      location: "USNYC",
      completed_at: ~U[2009-03-05 00:00:00Z]
    }

    {:ok, _event3} = CargoBookings.create_handling_event(cargo_abc123, attrs)

    handling_history = CargoBookings.lookup_handling_history(cargo_abc123.tracking_id)
    CargoBookings.derive_delivery_progress(cargo_abc123, handling_history)
  end

  def cargo_abc123_legs(voyages) do
    [
      %{
        voyage_id: voyage_id_for(voyages, :voyage_cnhkg_usnyc),
        load_location: "CNHKG",
        unload_location: "USNYC",
        load_time: ~U[2009-03-02 00:00:00Z],
        unload_time: ~U[2009-03-05 00:00:00Z]
      },
      %{
        voyage_id: voyage_id_for(voyages, :voyage_usnyc_usdal),
        load_location: "USNYC",
        unload_location: "USDAL",
        load_time: ~U[2009-03-06 00:00:00Z],
        unload_time: ~U[2009-03-08 00:00:00Z]
      },
      %{
        voyage_id: voyage_id_for(voyages, :voyage_usdal_fihel),
        load_location: "USDAL",
        unload_location: "FIHEL",
        load_time: ~U[2009-03-09 00:00:00Z],
        unload_time: ~U[2009-03-12 00:00:00Z]
      }
    ]
  end

  def load_cargo_jkl567(voyages) do
    # Cargo JKL567

    itinerary = %{
      legs: cargo_jkl567_legs(voyages)
    }

    attrs =
      %{
        tracking_id: "JKL567",
        route_specification: %{
          origin: "CNHGH",
          destination: "SESTO",
          arrival_deadline: ~U[2009-03-18 00:00:00Z]
        }
      }
      |> CargoBookings.assign_cargo_to_route(itinerary)

    {:ok, cargo_jkl567} = CargoBookings.create_cargo(attrs)

    attrs = %{
      event_type: "RECEIVE",
      voyage_id: nil,
      location: "CNHGH",
      completed_at: ~U[2009-03-01 00:00:00Z]
    }

    {:ok, _event1} = CargoBookings.create_handling_event(cargo_jkl567, attrs)

    attrs = %{
      event_type: "LOAD",
      voyage_id: voyage_id_for(voyages, :voyage_cnhkg_usnyc),
      location: "CNHGH",
      completed_at: ~U[2009-03-03 00:00:00Z]
    }

    {:ok, _event2} = CargoBookings.create_handling_event(cargo_jkl567, attrs)

    attrs = %{
      event_type: "UNLOAD",
      voyage_id: voyage_id_for(voyages, :voyage_cnhkg_usnyc),
      location: "USNYC",
      completed_at: ~U[2009-03-05 00:00:00Z]
    }

    {:ok, _event3} = CargoBookings.create_handling_event(cargo_jkl567, attrs)

    attrs = %{
      event_type: "LOAD",
      voyage_id: voyage_id_for(voyages, :voyage_cnhkg_usnyc),
      location: "USNYC",
      completed_at: ~U[2009-03-06 00:00:00Z]
    }

    {:ok, _event4} = CargoBookings.create_handling_event(cargo_jkl567, attrs)

    handling_history = CargoBookings.lookup_handling_history(cargo_jkl567.tracking_id)
    CargoBookings.derive_delivery_progress(cargo_jkl567, handling_history)
  end

  def cargo_jkl567_legs(voyages) do
    [
      %{
        voyage_id: voyage_id_for(voyages, :voyage_cnhkg_usnyc),
        load_location: "CNHGH",
        unload_location: "USNYC",
        load_time: ~U[2009-03-03 00:00:00Z],
        unload_time: ~U[2009-03-05 00:00:00Z]
      },
      %{
        voyage_id: voyage_id_for(voyages, :voyage_usnyc_usdal),
        load_location: "USNYC",
        unload_location: "USDAL",
        load_time: ~U[2009-03-06 00:00:00Z],
        unload_time: ~U[2009-03-08 00:00:00Z]
      },
      %{
        voyage_id: voyage_id_for(voyages, :voyage_usdal_fihel),
        load_location: "USDAL",
        unload_location: "SESTO",
        load_time: ~U[2009-03-09 00:00:00Z],
        unload_time: ~U[2009-03-11 00:00:00Z]
      }
    ]
  end

  def voyage_cnhkg_usnyc() do
    # Voyage number 0100S (by ship)
    # Hongkong - Hangzou - Tokyo - Melbourne - New York
    VoyageBuilder.init("0100S", "CNHKG")
    |> VoyageBuilder.add_movement(
      "CNHGH",
      ~U[2008-10-01 12:00:00Z],
      ~U[2008-10-03 14:30:00Z]
    )
    |> VoyageBuilder.add_movement(
      "JPTOK",
      ~U[2008-10-03 21:00:00Z],
      ~U[2008-10-06 06:15:00Z]
    )
    |> VoyageBuilder.add_movement(
      "AUMEL",
      ~U[2008-10-06 11:00:00Z],
      ~U[2008-10-12 11:30:00Z]
    )
    |> VoyageBuilder.add_movement(
      "USNYC",
      ~U[2008-10-14 12:00:00Z],
      ~U[2008-10-13 23:10:00Z]
    )
    |> VoyageBuilder.build()
  end

  ## From SampleVoyages.java

  def voyage_usnyc_usdal() do
    # Voyage number 0200T (by train)
    # New York - Chicago - Dallas
    VoyageBuilder.init("0200T", "USNYC")
    |> VoyageBuilder.add_movement(
      "USCHI",
      ~U[2008-10-24 07:00:00Z],
      ~U[2008-10-24 17:45:00Z]
    )
    |> VoyageBuilder.add_movement(
      "USDAL",
      ~U[2008-10-24 21:25:00Z],
      ~U[2008-10-15 19:30:00Z]
    )
    |> VoyageBuilder.build()
  end

  def voyage_usdal_fihel() do
    # Voyage number 0300A (by airplane)
    # Dallas - Hamburg - Stockholm - Helsinki
    VoyageBuilder.init("0300A", "USDAL")
    |> VoyageBuilder.add_movement(
      "DEHAM",
      ~U[2008-10-29 03:30:00Z],
      ~U[2008-10-31 14:00:00Z]
    )
    |> VoyageBuilder.add_movement(
      "SESTO",
      ~U[2008-11-01 15:20:00Z],
      ~U[2008-11-01 18:40:00Z]
    )
    |> VoyageBuilder.add_movement(
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
    |> VoyageBuilder.add_movement(
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
    |> VoyageBuilder.add_movement(
      "NLRTM",
      ~U[2008-11-04 05:50:00Z],
      ~U[2008-11-06 14:10:00Z]
    )
    |> VoyageBuilder.add_movement(
      "CNSHA",
      ~U[2008-11-10 21:45:00Z],
      ~U[2008-11-22 16:40:00Z]
    )
    |> VoyageBuilder.add_movement(
      "CNHKG",
      ~U[2008-11-24 07:00:00Z],
      ~U[2008-11-28 13:37:00Z]
    )
    |> VoyageBuilder.build()
  end

  def generate() do
    # Locations are read-only in memory

    # Voyages
    voyages =
      Enum.reduce(
        [
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

    load_cargo_abc123(voyages)
    load_cargo_jkl567(voyages)

    :ok
  end

  ## Utilities

  def ts(hours) do
    DateTime.add(@base_time, hours * 3600, :second)
  end

  def voyage_id_for(_voyages, nil), do: nil

  def voyage_id_for(voyages, name) do
    Map.fetch!(voyages, name) |> Map.fetch!(:id)
  end
end
