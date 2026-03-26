defmodule HexaRail.Simulation.Engine do
  use GenServer
  require Logger
  alias HexaRail.Repo
  alias HexaRail.RailwayNif
  alias HexaRail.GTFS.{Stop, Trip, StopTime}
  alias HexaRail.Data.Parser
  alias Phoenix.PubSub

  # 1 tick = 1000ms real time.
  @tick_interval_ms 1000
  @time_dilation 60 

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_resource, do: GenServer.call(__MODULE__, :get_resource, :infinity)
  def get_status, do: GenServer.call(__MODULE__, :get_status)
  def pause, do: GenServer.call(__MODULE__, :pause)
  def resume, do: GenServer.call(__MODULE__, :resume)

  def init(_) do
    Logger.info("Simulation Engine initializing...")
    resource = RailwayNif.init_network()
    
    # Background loader with progress reporting
    Task.start(fn -> perform_ignite_sequence(resource) end)

    {:ok, %{status: :loading, resource: resource, current_time: 8 * 3600, message: "System Wake-up", progress: 0}}
  end

  defp perform_ignite_sequence(resource) do
    report_progress(0, "Analyzing Physical Infrastructure...")
    
    # 1. Stops
    stops = Repo.all(Stop)
    RailwayNif.load_stops(resource, stops)
    report_progress(10, "100,000 Station Nodes Indexed")

    # 2. Topology
    topology_path = Path.join([:code.priv_dir(:hexarail), "data/raw/2026/20260318/topology.geojson"])
    if File.exists?(topology_path) do
      tracks = topology_path |> File.read!() |> Jason.decode!() |> Parser.extract_segments()
      RailwayNif.load_tracks(resource, tracks)
    end
    report_progress(25, "Physical Rail Geometry Linked (KD-Tree Active)")

    # 3. OSM
    osm_dir = Path.join([:code.priv_dir(:hexarail), "data/raw/osm"])
    if File.dir?(osm_dir) do
      Path.wildcard(Path.join(osm_dir, "*_micro.json"))
      |> Enum.each(fn file ->
        # Use Rust to parse the large JSON directly
        case RailwayNif.load_osm_from_json(resource, file) do
          {:ok, _} -> :ok
          _ -> :error
        end
      end)
      RailwayNif.stitch_osm_to_macro(resource)
    end
    report_progress(40, "Micro-Topology (OSM) Stitched to Hubs")
    :erlang.garbage_collect()

    # 4. StopTimes & STIG Matrix
    snapshot_path = Path.join([:code.priv_dir(:hexarail), "data", "stig_snapshot.bin"])

    if File.exists?(snapshot_path) do
      report_progress(60, "Zero-Copy Deserialization: Thawing STIG Snapshot...")
      case RailwayNif.thaw_state(resource, snapshot_path) do
        "ok" -> 
          report_progress(95, "STIG Matrix Restored from Cold Storage.")
        {:ok, _} -> 
          report_progress(95, "STIG Matrix Restored from Cold Storage.")
        {:error, reason} ->
          require Logger
          Logger.error("Failed to thaw state: #{inspect(reason)}. Rebuilding from DB...")
          build_and_freeze_stig(resource, snapshot_path)
        err ->
          require Logger
          Logger.error("Failed to thaw state (unknown): #{inspect(err)}. Rebuilding from DB...")
          build_and_freeze_stig(resource, snapshot_path)
      end
    else
      build_and_freeze_stig(resource, snapshot_path)
    end
    
    report_progress(100, "All Systems Green. Launching.")
    send(HexaRail.Simulation.Engine, :data_ready)
  end

  defp build_and_freeze_stig(resource, snapshot_path) do
    total_st = 19_169_401
    Repo.transaction(fn ->
      StopTime
      |> Repo.stream(max_rows: 100_000)
      |> Stream.chunk_every(100_000)
      |> Stream.with_index()
      |> Enum.each(fn {chunk, index} ->
        RailwayNif.load_stop_times(resource, chunk)
        prog = 40 + round((index * 100_000 / total_st) * 50)
        report_progress(prog, "Ingesting Schedule Matrix: #{prog}%")
      end)
    end, timeout: :infinity)

    report_progress(95, "Finalizing Spatio-Temporal Interval Graph...")
    RailwayNif.finalize_temporal_graph(resource)

    report_progress(98, "Zero-Copy: Freezing STIG to disk...")
    case RailwayNif.freeze_state(resource, snapshot_path) do
      "ok" -> require Logger; Logger.info("STIG state frozen to #{snapshot_path}")
      {:ok, _} -> require Logger; Logger.info("STIG state frozen to #{snapshot_path}")
      {:error, reason} -> require Logger; Logger.error("Failed to freeze STIG: #{inspect(reason)}")
      err -> require Logger; Logger.error("Failed to freeze STIG (unknown): #{inspect(err)}")
    end
  end

  defp report_progress(percent, msg) do
    Logger.info("[IGNITION] #{percent}% - #{msg}")
    PubSub.broadcast(HexaRail.PubSub, "simulation:switzerland", {:loading_progress, percent, msg})
    # Update internal state via cast
    GenServer.cast(__MODULE__, {:update_progress, percent, msg})
  end

  def handle_cast({:update_progress, p, m}, state) do
    {:noreply, %{state | progress: p, message: m}}
  end

  def handle_call(:get_status, _from, state), do: {:reply, state, state}
  def handle_call(:get_resource, _from, state), do: {:reply, state.resource, state}
  def handle_call(:pause, _from, state), do: {:reply, :ok, %{state | status: :paused}}
  def handle_call(:resume, _from, state) do
    if state.status == :paused, do: Process.send_after(self(), :tick, @tick_interval_ms)
    {:reply, :ok, %{state | status: :running}}
  end

  def handle_info(:data_ready, state) do
    Process.send_after(self(), :tick, @tick_interval_ms)
    {:noreply, %{state | status: :running}}
  end

  def handle_info(:tick, %{status: :running, resource: resource, current_time: time} = state) do
    positions = RailwayNif.get_active_positions(resource, time)
    Logger.info("[TICK] Time: #{time} | Active Trains: #{length(positions)}")
    
    # Binary Payload: [trip_id:32, head_lon:32f, head_lat:32f, tail_lon:32f, tail_lat:32f, alt:32f, heading:16i, pitch:16i, roll:16i, speed:16u] = 32 bytes
    binary_payload = 
      for pos <- positions, into: <<>> do
        <<pos.trip_id::32, pos.head_lon::32-float, pos.head_lat::32-float, pos.tail_lon::32-float, pos.tail_lat::32-float, pos.alt::32-float, round(pos.heading)::signed-16, round(pos.pitch)::signed-16, round(pos.roll)::signed-16, round(pos.velocity)::16>>
      end

    b64_payload = Base.encode64(binary_payload)
    PubSub.broadcast(HexaRail.PubSub, "simulation:switzerland", {:tick_binary, time, b64_payload})
    
    new_time = if time + @time_dilation >= 86400, do: 0, else: time + @time_dilation
    Process.send_after(self(), :tick, @tick_interval_ms)
    {:noreply, %{state | current_time: new_time}}
  end
  def handle_info(:tick, state), do: {:noreply, state}
  def handle_info({:loading_progress, _, _}, state), do: {:noreply, state}
end
