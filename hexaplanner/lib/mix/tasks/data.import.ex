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

  alias HexaPlanner.Repo

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

    total_start = System.monotonic_time()

    import_with_stats("Feed Info", Path.join(data_dir, "feed_info.txt"), "gtfs_feed_info", fn p ->
      Importer.import_feed_info(p)
    end)

    import_with_stats("Agency", Path.join(data_dir, "agency.txt"), "gtfs_agency", fn p ->
      Importer.import_agency(p)
    end)

    import_with_stats("Routes", Path.join(data_dir, "routes.txt"), "gtfs_routes", fn p ->
      Importer.import_routes(p)
    end)

    import_with_stats("Stops", Path.join(data_dir, "stops.txt"), "gtfs_stops", fn p ->
      Importer.import_stops(p)
    end)

    import_with_stats("Calendars", Path.join(data_dir, "calendar.txt"), "gtfs_calendars", fn p ->
      Importer.import_calendars(p)
    end)

    import_with_stats(
      "Calendar Dates",
      Path.join(data_dir, "calendar_dates.txt"),
      "gtfs_calendar_dates",
      fn p ->
        Importer.import_calendar_dates(p)
      end
    )

    import_with_stats("Trips", Path.join(data_dir, "trips.txt"), "gtfs_trips", fn p ->
      Importer.import_trips(p)
    end)

    import_with_stats(
      "Frequencies",
      Path.join(data_dir, "frequencies.txt"),
      "gtfs_frequencies",
      fn p ->
        Importer.import_frequencies(p)
      end
    )

    import_with_stats(
      "Stop Times",
      Path.join(data_dir, "stop_times.txt"),
      "gtfs_stop_times",
      fn p ->
        Importer.import_stop_times(p)
      end
    )

    import_with_stats("Transfers", Path.join(data_dir, "transfers.txt"), "gtfs_transfers", fn p ->
      Importer.import_transfers(p)
    end)

    total_end = System.monotonic_time()
    total_duration = System.convert_time_unit(total_end - total_start, :native, :second)

    Logger.info(
      "🎉 Global Ingestion Complete in #{total_duration}s! The Digital Twin is fully synchronized."
    )
  end

  defp import_with_stats(name, file_path, table_name, func) do
    # Count source lines (efficiently)
    {wc_out, 0} = System.cmd("wc", ["-l", file_path])
    [line_count_str | _] = String.split(String.trim(wc_out), " ")
    source_count = String.to_integer(line_count_str) - 1

    # Get DB count before
    %Postgrex.Result{rows: [[count_before]]} =
      Repo.query!("SELECT count(*) FROM #{table_name}", [], log: false)

    Logger.info(
      "Importing #{name}: [Current DB: #{count_before} entries | Source File: #{source_count} entries]"
    )

    start_time = System.monotonic_time()

    # Execute import
    func.(file_path)

    # Get DB count after
    %Postgrex.Result{rows: [[count_after]]} =
      Repo.query!("SELECT count(*) FROM #{table_name}", [], log: false)

    imported_count = count_after - count_before
    end_time = System.monotonic_time()
    duration = System.convert_time_unit(end_time - start_time, :native, :millisecond) / 1000

    Logger.info(
      "✅ #{name} ingestion finished: +#{imported_count} new entries in #{Float.round(duration, 2)}s"
    )
  end
end
