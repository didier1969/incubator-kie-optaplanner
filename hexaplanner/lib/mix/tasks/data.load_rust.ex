defmodule Mix.Tasks.Data.LoadRust do
  @shortdoc "Loads the entire PostgreSQL dataset into the Rust Data Plane for stress testing"
  use Mix.Task
  require Logger
  alias HexaPlanner.Repo
  alias HexaPlanner.GTFS.{Stop, Trip, StopTime}
  alias HexaPlanner.SolverNif

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    
    Logger.info("Initializing Rust Network Manager...")
    resource = SolverNif.init_network()

    Logger.info("Loading 100% of Stops into Rust...")
    # Now we use the abbreviation field we added to the DB
    stops = Repo.all(Stop)
    SolverNif.load_stops(resource, stops)
    Logger.info("✅ Stops loaded.")

    Logger.info("Loading 100% of Calendars & Exceptions into Rust...")
    calendars = Repo.all(HexaPlanner.GTFS.Calendar)
    SolverNif.load_calendars(resource, calendars)

    # Calendar dates are high volume (6M+), stream them
    Repo.transaction(fn ->
      HexaPlanner.GTFS.CalendarDate
      |> Repo.stream(max_rows: 50_000)
      |> Stream.chunk_every(50_000)
      |> Enum.each(fn chunk ->
        SolverNif.load_calendar_dates(resource, chunk)
        IO.write("c")
      end)
    end, timeout: :infinity)
    Logger.info("\n✅ Calendars loaded.")

    Logger.info("Loading 100% of Transfers into Rust...")
    transfers = Repo.all(HexaPlanner.GTFS.Transfer)
    SolverNif.load_transfers(resource, transfers)
    Logger.info("✅ Transfers loaded.")

    Logger.info("Loading Physical Rail Geometry (GeoJSON Curves)...")
    topology_path = Path.join([:code.priv_dir(:hexaplanner), "data/raw/2026/20260318/topology.geojson"])
    if File.exists?(topology_path) do
      tracks = 
        topology_path
        |> File.read!()
        |> Jason.decode!()
        |> HexaPlanner.Data.Parser.extract_segments()
      
      SolverNif.load_tracks(resource, tracks)
      Logger.info("✅ Physical topology loaded.")
    else
      Logger.warning("Topology file not found at #{topology_path}. Skipping.")
    end

    Logger.info("Loading 100% of Stop Times into Rust (~19 Million rows)...")
    # Stream in chunks to avoid BEAM memory spikes
    Repo.transaction(fn ->
      StopTime
      |> Repo.stream(max_rows: 50_000)
      |> Stream.chunk_every(50_000)
      |> Enum.each(fn chunk ->
        SolverNif.load_stop_times(resource, chunk)
        IO.write(".")
      end)
    end, timeout: :infinity)
    
    Logger.info("\nFinalizing STIG Graph in Rust (Fusion pass)...")
    edge_count = SolverNif.finalize_temporal_graph(resource)
    Logger.info("✅ All data loaded. STIG contains #{edge_count} edges.")

    Logger.info("Detecting Spatio-Temporal Conflicts (Sweep-Line)...")
    summary = SolverNif.detect_conflicts(resource)
    Logger.info("⚠️ Detected #{summary.total_conflicts} physical collisions (including headway violations) in the baseline schedule.")
    
    # Measure memory (approximate)
    :erlang.garbage_collect()
    mem = :erlang.memory(:total) / 1024 / 1024
    Logger.info("Current BEAM Memory usage: #{Float.round(mem, 2)} MB")
    Logger.info("The Rust Data Plane is now populated and ready for Phase 13.")
  end
end
