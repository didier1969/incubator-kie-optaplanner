defmodule Mix.Tasks.Data.Clean do
  @shortdoc "Purges all GTFS data from the PostgreSQL database"
  @moduledoc """
  This task cleans the Digital Twin by truncating all GTFS related tables.
  It uses CASCADE to ensure all dependencies (like stop_times) are also removed.
  """
  use Mix.Task
  require Logger
  alias HexaPlanner.Repo

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    Logger.info("🧹 Starting complete system purge...")

    tables = [
      "gtfs_stop_times",
      "gtfs_transfers",
      "gtfs_frequencies",
      "gtfs_trips",
      "gtfs_routes",
      "gtfs_agency",
      "gtfs_stops",
      "gtfs_calendars",
      "gtfs_calendar_dates",
      "gtfs_feed_info"
    ]

    # We use a single transaction for atomicity
    Repo.transaction(fn ->
      Enum.each(tables, fn table ->
        Repo.query!("TRUNCATE TABLE #{table} CASCADE", [], log: false)
        Logger.info("  - Table #{table} purged.")
      end)
    end)

    Logger.info("✅ System clean. All temporal and physical data has been removed.")
  end
end
