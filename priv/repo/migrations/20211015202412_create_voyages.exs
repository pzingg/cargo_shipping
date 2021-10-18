defmodule CargoShipping.Repo.Migrations.CreateVoyages do
  use Ecto.Migration

  def change do
    create table(:voyages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :voyage_number, :string, null: false
      add :schedule_items, {:array, :map}

      timestamps()
    end
  end
end
