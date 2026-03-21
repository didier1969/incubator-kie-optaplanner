defmodule HexaPlanner.GTFS.Importer do
  @moduledoc """
  Handles the streaming and bulk ingestion of GTFS static files
  into the PostgreSQL database.
  """
  alias HexaPlanner.GTFS.Stop
  alias HexaPlanner.Repo

  NimbleCSV.define(GTFSParser, separator: ",", escape: "\"")

  def import_stops(file_path) do
    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn [stop_id, stop_name, stop_lat, stop_lon] ->
      lat = String.to_float(stop_lat)
      lon = String.to_float(stop_lon)
      point = %Geo.Point{coordinates: {lon, lat}, srid: 4326}

      %{
        stop_id: stop_id,
        stop_name: stop_name,
        location: point
      }
    end)
    |> Stream.chunk_every(1000)
    |> Enum.each(fn chunk ->
      Repo.insert_all(Stop, chunk, on_conflict: :replace_all, conflict_target: :stop_id)
    end)
  end
end
