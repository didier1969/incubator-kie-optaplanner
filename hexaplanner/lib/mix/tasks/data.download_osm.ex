defmodule Mix.Tasks.Data.DownloadOsm do
  @shortdoc "Downloads OpenStreetMap micro-topology (switches, rails, platforms) for major Swiss stations"
  use Mix.Task
  require Logger
  alias HexaPlanner.Repo
  alias HexaPlanner.GTFS.Stop
  import Ecto.Query

  @overpass_url "https://overpass-api.de/api/interpreter"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    
    # We will fetch OSM data for the top major stations to prevent overloading the Overpass API.
    # We identify major stations by looking at parent stations with the most platform stops,
    # or by specifically querying known large hubs (Zurich, Bern, Basel, Lausanne, Geneva).
    
    # For this Phase 12I execution, we will focus on a subset of critical hubs to build the prototype.
    major_hubs = [
      "Zurich HB",
      "Bern",
      "Basel SBB",
      "Lausanne",
      "Genève"
    ]

    Logger.info("Starting Phase 12I: OSM Micro-Topology Extraction")
    
    # Ensure raw data directory exists
    target_dir = Path.join([:code.priv_dir(:hexaplanner), "data/raw/osm"])
    File.mkdir_p!(target_dir)

    Enum.each(major_hubs, fn hub_name ->
      Logger.info("Fetching coordinates for hub: #{hub_name}")
      # Get the parent station location
      stop = Repo.one(from s in Stop, where: ilike(s.stop_name, ^"#{hub_name}%") and is_nil(s.location_type), limit: 1)
      
      if stop do
        {lon, lat} = stop.location.coordinates
        
        # Define a bounding box around the station (roughly 2km x 2km)
        # 0.01 degrees is roughly 1km
        bbox = "#{lat - 0.015},#{lon - 0.02},#{lat + 0.015},#{lon + 0.02}"
        
        query = """
        [out:json][timeout:250];
        (
          way["railway"~"rail|switch|crossing"](#{bbox});
          node["railway"~"switch|crossing|railway_crossing"](#{bbox});
          way["public_transport"="platform"](#{bbox});
          way["railway"="platform"](#{bbox});
        );
        out body;
        >;
        out skel qt;
        """

        Logger.info("Downloading Overpass data for #{hub_name}...")
        
        case Req.post(@overpass_url, body: query, receive_timeout: 300_000) do
          {:ok, %{status: 200, body: body}} ->
            file_path = Path.join(target_dir, "#{String.replace(hub_name, " ", "_")}_micro.json")
            File.write!(file_path, Jason.encode!(body))
            Logger.info("✅ Saved OSM data for #{hub_name} to #{file_path}")
            
            # Sleep to respect Overpass API rate limits
            Process.sleep(5000)
            
          {:ok, response} ->
            Logger.error("Failed to fetch #{hub_name}. Status: #{response.status}")
            
          {:error, reason} ->
            Logger.error("Network error fetching #{hub_name}: #{inspect(reason)}")
        end
      else
        Logger.warning("Could not find stop in database for: #{hub_name}")
      end
    end)
    
    Logger.info("OSM Extraction complete. Data ready for Rust parsing.")
  end
end
