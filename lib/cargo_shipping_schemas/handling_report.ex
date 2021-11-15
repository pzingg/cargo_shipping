defmodule CargoShippingSchemas.HandlingReport do
  @moduledoc """
  The HandlingReport AGGREGATE.

  HandlingReports are usually created via the REST API.
  When validated, they trigger the asynchronous creation
  of a HandlingEvent.
  """
  use Ecto.Schema

  alias CargoShippingSchemas.HandlingEvent

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]
  schema "handling_reports" do
    field :event_type, Ecto.Enum, values: HandlingEvent.event_type_values()
    field :tracking_id, :string
    field :voyage_number, :string
    field :location, :string
    field :completed_at, :utc_datetime

    timestamps(inserted_at: :received_at, updated_at: false)
  end
end
