defmodule Mix.Tasks.Data.Download do
  @shortdoc "Downloads raw GTFS and GeoJSON data from SBB Open Data"
  @moduledoc """
  Downloads the physical topology (Liniennetz), operating points,
  and the full Swiss GTFS timetable. Saves them locally and extracts
  the ZIP archive.
  """
  use Mix.Task
  require Logger

  @topology_url "https://data.sbb.ch/api/explore/v2.1/catalog/datasets/linie-mit-polygon/exports/geojson"
  @stops_url "https://data.sbb.ch/api/explore/v2.1/catalog/datasets/dienststellen-gemass-opentransportdataswiss/exports/geojson"
  # This URL points to the 2026 Timetable GTFS Zip
  @gtfs_url "https://data.opentransportdata.swiss/dataset/3d2c18f9-9ef1-463f-a249-5c67604efd74/resource/04f4468f-ff4c-4468-9c82-1806a22ff3a0/download/gtfs_fp2026_20260318.zip"

  @impl Mix.Task
  def run(_) do
    Application.ensure_all_started(:req)
    
    # We use the version date as the folder name
    version_str = "20260318"
    year_str = String.slice(version_str, 0, 4)
    data_dir = Path.join([:code.priv_dir(:hexaplanner), "data/raw", year_str, version_str])
    
    File.mkdir_p!(data_dir)

    Logger.info("Saving datasets to #{data_dir}")

    Logger.info("Starting download of SBB Physical Topology (Liniennetz)...")
    download_and_save(@topology_url, Path.join(data_dir, "topology.geojson"))

    Logger.info("Starting download of SBB Operating Points (Stops)...")
    download_and_save(@stops_url, Path.join(data_dir, "stops.geojson"))

    gtfs_zip_path = Path.join(data_dir, "timetable.zip")
    Logger.info("Starting download of Swiss GTFS Timetable...")
    if download_and_save(@gtfs_url, gtfs_zip_path) == :ok do
      Logger.info("Extracting GTFS Timetable...")
      gtfs_dir = Path.join(data_dir, "gtfs")
      File.mkdir_p!(gtfs_dir)
      extract_zip(gtfs_zip_path, gtfs_dir)
    end
    
    Logger.info("All downloads and extractions completed successfully.")
  end

  defp download_and_save(url, target_path) do
    req = Req.new(url: url)
    
    case Req.get(req, into: File.stream!(target_path)) do
      {:ok, %Req.Response{status: 200}} ->
        Logger.info("Successfully saved to #{target_path}")
        :ok
      {:ok, %Req.Response{status: status}} ->
        Logger.error("Failed to download from #{url}. Status: #{status}")
        :error
      {:error, reason} ->
        Logger.error("Network error while downloading from #{url}: #{inspect(reason)}")
        :error
    end
  end

  defp extract_zip(zip_path, target_dir) do
    # Ensure unzip command is available in the shell
    case System.cmd("unzip", ["-o", zip_path, "-d", target_dir]) do
      {_, 0} -> Logger.info("Successfully extracted GTFS to #{target_dir}")
      {error_msg, _} -> Logger.error("Failed to extract zip: #{error_msg}")
    end
  end
end
