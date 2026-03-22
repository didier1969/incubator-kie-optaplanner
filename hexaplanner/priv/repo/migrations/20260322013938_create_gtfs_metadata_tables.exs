defmodule HexaPlanner.Repo.Migrations.CreateGtfsMetadataTables do
  use Ecto.Migration

  def change do
    create table(:gtfs_agency, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :original_agency_id, :string, null: false
      add :agency_name, :string, null: false
      add :agency_url, :string
      add :agency_timezone, :string
      add :agency_lang, :string
      add :agency_phone, :string
    end
    
    create unique_index(:gtfs_agency, [:original_agency_id])

    create table(:gtfs_routes, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :original_route_id, :string, null: false
      add :agency_id, references(:gtfs_agency, column: :id, type: :bigint, on_delete: :nilify_all)
      add :route_short_name, :string
      add :route_long_name, :string
      add :route_desc, :text
      add :route_type, :integer, null: false
    end

    create unique_index(:gtfs_routes, [:original_route_id])
    create index(:gtfs_routes, [:agency_id])

    create table(:gtfs_frequencies, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :trip_id, references(:gtfs_trips, column: :id, type: :bigint, on_delete: :delete_all), null: false
      add :start_time, :integer, null: false
      add :end_time, :integer, null: false
      add :headway_secs, :integer, null: false
      add :exact_times, :integer
    end

    create index(:gtfs_frequencies, [:trip_id])

    create table(:gtfs_feed_info, primary_key: false) do
      add :feed_publisher_name, :string, null: false
      add :feed_publisher_url, :string, null: false
      add :feed_lang, :string, null: false
      add :feed_start_date, :integer, null: false
      add :feed_end_date, :integer, null: false
      add :feed_version, :string
    end
  end
end
