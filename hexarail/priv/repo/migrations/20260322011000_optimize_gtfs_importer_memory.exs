defmodule HexaRail.Repo.Migrations.OptimizeGtfsImporterMemory do
  use Ecto.Migration

  def up do
    # Create temporary unlogged tables to act as our dictionaries in PostgreSQL directly
    execute("CREATE UNLOGGED TABLE gtfs_stops_dict (original_id text PRIMARY KEY, id bigint NOT NULL)")
    execute("CREATE UNLOGGED TABLE gtfs_trips_dict (original_id text PRIMARY KEY, id bigint NOT NULL)")
    
    # We will populate these using simple INSERTs from Elixir, and then use SQL to resolve the IDs.
  end

  def down do
    execute("DROP TABLE IF EXISTS gtfs_stops_dict")
    execute("DROP TABLE IF EXISTS gtfs_trips_dict")
  end
end
