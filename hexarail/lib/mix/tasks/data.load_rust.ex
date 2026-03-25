defmodule Mix.Tasks.Data.LoadRust do
  @shortdoc "Loads the entire PostgreSQL dataset into the Rust Data Plane for stress testing"
  use Mix.Task
  require Logger
  alias HexaRail.Repo
  alias HexaRail.GTFS.{Stop, Trip, StopTime}
  alias HexaRail.RailwayNif

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    
    Logger.info("Initializing Rust Network Manager...")
    resource = RailwayNif.init_network()

    Logger.info("Loading 100% of Stops into Rust...")
    # Now we use the abbreviation field we added to the DB
    stops = Repo.all(Stop)
    RailwayNif.load_stops(resource, stops)
    Logger.info("✅ Stops loaded.")

    Logger.info("Loading 100% of Calendars & Exceptions into Rust...")
    calendars = Repo.all(HexaRail.GTFS.Calendar)
    RailwayNif.load_calendars(resource, calendars)

    # Calendar dates are high volume (6M+), stream them
    Repo.transaction(fn ->
      HexaRail.GTFS.CalendarDate
      |> Repo.stream(max_rows: 50_000)
      |> Stream.chunk_every(50_000)
      |> Enum.each(fn chunk ->
        RailwayNif.load_calendar_dates(resource, chunk)
        IO.write("c")
      end)
    end, timeout: :infinity)
    Logger.info("\n✅ Calendars loaded.")

    Logger.info("Loading 100% of Transfers into Rust...")
    transfers = Repo.all(HexaRail.GTFS.Transfer)
    RailwayNif.load_transfers(resource, transfers)
    Logger.info("✅ Transfers loaded.")

    Logger.info("Inferring and Loading Fleet Profiles (Rolling Stock)...")
    # We load trips in chunks to assign physical fleet properties
    Repo.transaction(fn ->
      Trip
      |> Repo.stream(max_rows: 50_000)
      |> Stream.chunk_every(50_000)
      |> Enum.each(fn chunk ->
        profiles_map = 
          chunk
          |> Enum.map(fn trip -> 
            profile = HexaRail.Fleet.infer_profile(trip.route_id)
            # Map Elixir Struct to NIF Struct
            nif_profile = %{profile | __struct__: HexaRail.Fleet.RollingStockProfile}
            {trip.id, nif_profile}
          end)
          |> Map.new()
        RailwayNif.load_fleet(resource, profiles_map)
      end)
    end, timeout: :infinity)
    Logger.info("✅ Fleet loaded.")

    Logger.info("Loading Physical Rail Geometry (GeoJSON Curves)...")
    topology_path = Path.join([:code.priv_dir(:hexarail), "data/raw/2026/20260318/topology.geojson"])
    if File.exists?(topology_path) do
      tracks = 
        topology_path
        |> File.read!()
        |> Jason.decode!()
        |> HexaRail.Data.Parser.extract_segments()
      
      RailwayNif.load_tracks(resource, tracks)
      Logger.info("✅ Physical topology loaded.")
    else
      Logger.warning("Topology file not found at #{topology_path}. Skipping.")
    end

    Logger.info("Loading Micro-Topology (OSM)...")
    osm_dir = Path.join([:code.priv_dir(:hexarail), "data/raw/osm"])
    if File.dir?(osm_dir) do
      osm_files = Path.wildcard(Path.join(osm_dir, "*_micro.json"))
      Enum.each(osm_files, fn file ->
        {nodes, ways} = HexaRail.Data.OsmParser.parse_file(file)
        mapped_nodes = Enum.map(nodes, fn n -> %{n | __struct__: HexaRail.Domain.OsmNode} end)
        mapped_ways = Enum.map(ways, fn w -> %{w | __struct__: HexaRail.Domain.OsmWay} end)
        RailwayNif.load_osm(resource, mapped_nodes, mapped_ways)
      end)
      Logger.info("Stitching OSM Micro-Topology to GeoJSON Macro-Topology...")
      RailwayNif.stitch_osm_to_macro(resource)
      Logger.info("✅ Micro-topology loaded and stitched.")
    end

    Logger.info("Loading 100% of Stop Times into Rust (~19 Million rows)...")
    # Stream in chunks to avoid BEAM memory spikes
    Repo.transaction(fn ->
      StopTime
      |> Repo.stream(max_rows: 50_000)
      |> Stream.chunk_every(50_000)
      |> Enum.each(fn chunk ->
        RailwayNif.load_stop_times(resource, chunk)
        IO.write(".")
      end)
    end, timeout: :infinity)
    
    Logger.info("\nFinalizing STIG Graph in Rust (Fusion pass)...")
    edge_count = RailwayNif.finalize_temporal_graph(resource)
    Logger.info("✅ All data loaded. STIG contains #{edge_count} edges.")

    Logger.info("Detecting Spatio-Temporal Conflicts (Sweep-Line)...")
    summary = RailwayNif.detect_conflicts(resource)
    Logger.info("⚠️ Detected #{summary.total_conflicts} physical collisions (including headway violations) in the baseline schedule.")
    
    # Measure memory (approximate)
    :erlang.garbage_collect()
    mem = :erlang.memory(:total) / 1024 / 1024
    Logger.info("Current BEAM Memory usage: #{Float.round(mem, 2)} MB")
    Logger.info("The Rust Data Plane is now populated and ready for Phase 13.")
  end
end
