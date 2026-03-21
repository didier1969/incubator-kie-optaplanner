defmodule HexaPlanner.Repo.Migrations.CreateGtfsStops do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS postgis")

    create table(:gtfs_stops, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :original_stop_id, :string, null: false
      add :stop_name, :string, null: false
      add :location, :geometry, null: false
    end

    create unique_index(:gtfs_stops, [:original_stop_id])
    execute("CREATE INDEX gtfs_stops_location_index ON gtfs_stops USING GIST (location)")
  end

  def down do
    drop index(:gtfs_stops, [:original_stop_id])
    execute("DROP INDEX gtfs_stops_location_index")
    drop table(:gtfs_stops)
  end
end
