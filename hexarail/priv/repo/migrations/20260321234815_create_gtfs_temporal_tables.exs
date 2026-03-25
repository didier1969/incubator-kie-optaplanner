defmodule HexaRail.Repo.Migrations.CreateGtfsTemporalTables do
  use Ecto.Migration

  def change do
    create table(:gtfs_trips, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :original_trip_id, :string, null: false
      add :route_id, :string, null: false
      add :service_id, :string, null: false
    end

    create unique_index(:gtfs_trips, [:original_trip_id])
    create index(:gtfs_trips, [:service_id])
    create index(:gtfs_trips, [:route_id])

    create table(:gtfs_stop_times, primary_key: false) do
      add :trip_id, references(:gtfs_trips, column: :id, type: :bigint, on_delete: :delete_all), null: false
      add :stop_id, references(:gtfs_stops, column: :id, type: :bigint, on_delete: :delete_all), null: false
      add :arrival_time, :integer, null: false
      add :departure_time, :integer
      add :stop_sequence, :integer, null: false
    end

    # Composite indices for standard GTFS queries and data integrity
    create index(:gtfs_stop_times, [:stop_id, :departure_time])
    create unique_index(:gtfs_stop_times, [:trip_id, :stop_sequence])

    create table(:gtfs_transfers, primary_key: false) do
      add :from_stop_id, references(:gtfs_stops, column: :id, type: :bigint, on_delete: :delete_all), null: false
      add :to_stop_id, references(:gtfs_stops, column: :id, type: :bigint, on_delete: :delete_all), null: false
      add :transfer_type, :integer, null: false
      add :min_transfer_time, :integer
      add :from_trip_id, references(:gtfs_trips, column: :id, type: :bigint, on_delete: :nilify_all)
      add :to_trip_id, references(:gtfs_trips, column: :id, type: :bigint, on_delete: :nilify_all)
    end

    create index(:gtfs_transfers, [:from_stop_id])
  end
end
