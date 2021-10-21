defmodule CargoShipping.Repo.Migrations.CreateHandlingReports do
  use Ecto.Migration

  def change do
    create table(:handling_reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :string
      add :tracking_id, :string
      add :voyage_number, :string
      add :location, :string
      add :completed_at, :utc_datetime

      timestamps(inserted_at: :received_at, updated_at: false)
    end
  end
end
