defmodule HexaPlanner.Repo.Migrations.AddMissingGtfsFields do
  use Ecto.Migration

  def change do
    alter table(:gtfs_stops) do
      add :location_type, :integer
      add :parent_station, :string
      add :platform_code, :string
    end

    alter table(:gtfs_trips) do
      add :trip_headsign, :string
      add :trip_short_name, :string
      add :direction_id, :integer
      add :block_id, :string
      add :hints, :text
    end

    alter table(:gtfs_stop_times) do
      add :pickup_type, :integer
      add :drop_off_type, :integer
    end
  end
end
