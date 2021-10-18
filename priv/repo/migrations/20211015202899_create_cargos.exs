defmodule CargoShipping.Repo.Migrations.Createcargos do
  use Ecto.Migration

  def change do
    create table(:cargos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tracking_id, :string, null: false
      add :origin, :string, null: false
      add :route_specification, :map
      add :itinerary, :map
      add :delivery, :map

      timestamps()
    end

    create unique_index(:cargos, [:tracking_id])
  end
end
