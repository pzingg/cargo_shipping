defmodule CargoShipping.Repo.Migrations.CreateHandlingEvents do
  use Ecto.Migration

  def change do
    create table(:handling_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :string, null: false
      add :voyage_id, :binary_id
      add :location, :string
      add :completed_at, :utc_datetime
      add :cargo_id, references(:cargos, type: :binary_id)

      timestamps(inserted_at: :registered_at, updated_at: false)
    end
  end
end
