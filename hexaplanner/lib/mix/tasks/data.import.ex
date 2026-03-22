defmodule Mix.Tasks.Data.Import do
  @shortdoc "Imports raw downloaded GTFS data into the HexaPlanner PostgreSQL database"
  @moduledoc """
  This task automates the process of importing the massive GTFS datasets
  (stops, trips, stop_times) into the database using optimized staging tables.

  It expects the data to have been downloaded first via `mix data.download`.
  """
  use Mix.Task
  require Logger
  alias HexaPlanner.GTFS.Importer

  @impl Mix.Task
  def run(args) do
    # Start the Ecto Repo
    Mix.Task.run("app.start")

    # Default to the version we know exists, or allow override
    version_str = List.first(args) || "20260318"
    year_str = String.slice(version_str, 0, 4)

    data_dir =
      Path.join([:code.priv_dir(:hexaplanner), "data/raw", year_str, version_str, "gtfs"])

    unless File.exists?(data_dir) do
      Logger.error(
        "Data directory not found at #{data_dir}. Please run `mix data.download` first."
      )

      exit({:shutdown, 1})
    end

    stops_path = Path.join(data_dir, "stops.txt")
    trips_path = Path.join(data_dir, "trips.txt")
    stop_times_path = Path.join(data_dir, "stop_times.txt")
    transfers_path = Path.join(data_dir, "transfers.txt")
    calendar_path = Path.join(data_dir, "calendar.txt")
    calendar_dates_path = Path.join(data_dir, "calendar_dates.txt")

    Logger.info("Starting ingestion of GTFS Stops...")
    Importer.import_stops(stops_path)
    Logger.info("✅ Stops imported successfully.")

    Logger.info("Starting ingestion of GTFS Calendars...")
    Importer.import_calendars(calendar_path)
    Importer.import_calendar_dates(calendar_dates_path)
    Logger.info("✅ Calendars imported successfully.")

    Logger.info("Starting ingestion of GTFS Trips...")
    Importer.import_trips(trips_path)
    Logger.info("✅ Trips imported successfully.")

    Logger.info("Starting massive ingestion of GTFS Stop Times (~20 Million rows)...")
    Logger.info("This process uses PostgreSQL unlogged tables and may take 2-5 minutes.")
    Importer.import_stop_times(stop_times_path)
    Logger.info("✅ Stop Times imported successfully.")

    Logger.info("Starting ingestion of GTFS Transfers...")
    Importer.import_transfers(transfers_path)
    Logger.info("✅ Transfers imported successfully.")

    Logger.info("🎉 Database ingestion complete! The Digital Twin is ready.")
  end
end
