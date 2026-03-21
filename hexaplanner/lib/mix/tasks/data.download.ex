defmodule Mix.Tasks.Data.Download do
  @shortdoc "Downloads raw GTFS and GeoJSON data from SBB Open Data"
  @moduledoc """
  Downloads the physical topology (Liniennetz) and the operating points
  from the Swiss Open Data portals and saves them locally as raw JSON
  files to act as a local S3 cache.
  """
  use Mix.Task
  require Logger

  @topology_url "https://data.sbb.ch/api/explore/v2.1/catalog/datasets/linie-mit-polygon/exports/geojson"
  @stops_url "https://data.sbb.ch/api/explore/v2.1/catalog/datasets/dienststellen-gemass-opentransportdataswiss/exports/geojson"

  @impl Mix.Task
  def run(_) do
    # Ensure req is started
    Application.ensure_all_started(:req)
    
    data_dir = Path.join(:code.priv_dir(:hexaplanner), "data/raw")
    File.mkdir_p!(data_dir)

    Logger.info("Starting download of SBB Physical Topology (Liniennetz)...")
    download_and_save(@topology_url, Path.join(data_dir, "topology.geojson"))

    Logger.info("Starting download of SBB Operating Points (Stops)...")
    download_and_save(@stops_url, Path.join(data_dir, "stops.geojson"))
    
    Logger.info("All downloads completed successfully.")
  end

  defp download_and_save(url, target_path) do
    # Stream the download to disk to avoid blowing up memory with 100MB+ JSON files
    req = Req.new(url: url)
    
    case Req.get(req, into: File.stream!(target_path)) do
      {:ok, %Req.Response{status: 200}} ->
        Logger.info("Successfully saved to #{target_path}")
      {:ok, %Req.Response{status: status}} ->
        Logger.error("Failed to download from #{url}. Status: #{status}")
      {:error, reason} ->
        Logger.error("Network error while downloading from #{url}: #{inspect(reason)}")
    end
  end
end
