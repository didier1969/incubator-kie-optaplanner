defmodule Mix.Tasks.Data.DownloadOsm do
  @shortdoc "Downloads OpenStreetMap micro-topology (switches, rails, platforms) for all of Switzerland"
  use Mix.Task
  require Logger

  @overpass_url "https://overpass-api.de/api/interpreter"

  @impl Mix.Task
  def run(_args) do
    # Ensure req and its dependencies are started for HTTP requests
    Application.ensure_all_started(:telemetry)
    Application.ensure_all_started(:finch)
    Application.ensure_all_started(:req)
    # Start the app to get the Req.Finch supervisor tree if necessary, or just start Finch manually.
    Mix.Task.run("app.start")
    
    Logger.info("Starting Phase 4 (Scénario D): OSM Micro-Topology Extraction for Switzerland (150 Mo)")

    # Ensure raw data directory exists
    target_dir = Path.join([:code.priv_dir(:hexaplanner), "data/raw/osm"])
    File.mkdir_p!(target_dir)

    query = """
    [out:json][timeout:900];
    area["ISO3166-1"="CH"][admin_level=2]->.searchArea;
    (
      way["railway"~"rail|switch|crossing"](area.searchArea);
      node["railway"~"switch|crossing|railway_crossing"](area.searchArea);
      way["public_transport"="platform"](area.searchArea);
      way["railway"="platform"](area.searchArea);
    );
    out body;
    >;
    out skel qt;
    """

    Logger.info("Downloading Overpass data... This might take a while.")
    file_path = Path.join(target_dir, "switzerland_micro.json")

    case Req.post(@overpass_url, body: query, receive_timeout: 900_000) do
      {:ok, %{status: 200, body: body}} ->
        File.write!(file_path, Jason.encode!(body))
        Logger.info("✅ Saved 150Mo OSM data to #{file_path}")

      {:ok, response} ->
        Logger.error("Failed to fetch OSM data. Status: #{response.status}")

      {:error, reason} ->
        Logger.error("Network error fetching OSM data: #{inspect(reason)}")
    end

    Logger.info("OSM Extraction complete. Data ready for Rust parsing.")
  end
end
