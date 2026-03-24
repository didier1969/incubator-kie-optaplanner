defmodule HexaPlanner.Repo.Migrations.CreateRollingStockTables do
  use Ecto.Migration

  def change do
    create table(:vehicles, primary_key: false) do
      add :id, :string, primary_key: true
      add :uic_number, :string, null: false
      add :model, :string, null: false
      add :mass_tonnes, :float, null: false
      add :length_meters, :float, null: false
      add :max_speed_kmh, :float, null: false
      add :acceleration_ms2, :float, null: false

      timestamps()
    end

    create unique_index(:vehicles, [:uic_number])

    create table(:compositions) do
      add :trip_id, references(:gtfs_trips, on_delete: :delete_all), null: false
      add :total_mass_tonnes, :float, null: false
      add :total_length_meters, :float, null: false

      timestamps()
    end

    create index(:compositions, [:trip_id])

    create table(:composition_vehicles) do
      add :composition_id, references(:compositions, on_delete: :delete_all), null: false
      add :vehicle_id, references(:vehicles, type: :string, on_delete: :delete_all), null: false
      add :position, :integer, null: false # Position in the train (1 = front)

      timestamps()
    end

    create unique_index(:composition_vehicles, [:composition_id, :position])
  end
end
