defmodule HexaPlanner.Repo.Migrations.CreateGtfsStops do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS postgis")

    create table(:gtfs_stops, primary_key: false) do
      add :stop_id, :string, primary_key: true
      add :stop_name, :string, null: false
      add :location, :geometry, null: false
    end
  end
end
