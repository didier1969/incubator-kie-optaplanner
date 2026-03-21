defmodule HexaPlanner.Repo.Migrations.CreateGtfsTemporalTables do
  use Ecto.Migration

  def change do
    create table(:gtfs_trips, primary_key: false) do
      add :trip_id, :string, primary_key: true
      add :route_id, :string, null: false
      add :service_id, :string, null: false
    end

    create table(:gtfs_stop_times, primary_key: false) do
      add :trip_id, references(:gtfs_trips, column: :trip_id, type: :string, on_delete: :delete_all), null: false
      add :arrival_time, :integer, null: false
      add :departure_time, :integer
      add :stop_id, references(:gtfs_stops, column: :stop_id, type: :string, on_delete: :delete_all), null: false
      add :stop_sequence, :integer, null: false
    end

    create index(:gtfs_stop_times, [:trip_id])
    create index(:gtfs_stop_times, [:stop_id])

    create table(:gtfs_transfers, primary_key: false) do
      add :from_stop_id, references(:gtfs_stops, column: :stop_id, type: :string, on_delete: :delete_all), null: false
      add :to_stop_id, references(:gtfs_stops, column: :stop_id, type: :string, on_delete: :delete_all), null: false
      add :transfer_type, :integer, null: false
      add :min_transfer_time, :integer
      add :from_trip_id, :string
      add :to_trip_id, :string
    end

    create index(:gtfs_transfers, [:from_stop_id])
    create index(:gtfs_transfers, [:to_stop_id])
  end
end
