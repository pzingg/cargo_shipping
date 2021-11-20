defmodule CargoShipping.Infra.Repo.Migrations.AddCargoVersion do
  use Ecto.Migration

  def change do
    alter table(:cargos) do
      remove :origin, :string, null: false
      add :created_version, :bigint, null: true
      add :version, :bigserial, null: false
    end

    alter table(:handling_reports) do
      add :version, :bigint, null: false
    end

    alter table(:handling_events) do
      add :version, :bigint, null: false
      add :handling_report_id, :binary_id, null: true
    end
  end
end
