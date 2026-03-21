defmodule HexaPlanner.GTFS.Importer do
  @moduledoc """
  Handles the streaming and bulk ingestion of GTFS static files
  into the PostgreSQL database.
  """
  alias HexaPlanner.GTFS.Stop
  alias HexaPlanner.GTFS.StopTime
  alias HexaPlanner.GTFS.Trip
  alias HexaPlanner.Repo
  import Ecto.Query

  NimbleCSV.define(GTFSParser, separator: ",", escape: "\"")

  def import_stops(file_path) do
    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn [stop_id, stop_name, stop_lat, stop_lon | _] ->
      lat = String.to_float(stop_lat)
      lon = String.to_float(stop_lon)
      point = %Geo.Point{coordinates: {lon, lat}, srid: 4326}

      %{
        original_stop_id: stop_id,
        stop_name: stop_name,
        location: point
      }
    end)
    |> Stream.chunk_every(1000)
    |> Enum.each(fn chunk ->
      Repo.insert_all(Stop, chunk, on_conflict: :replace_all, conflict_target: :original_stop_id)
    end)
  end

  def import_trips(file_path) do
    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn [route_id, service_id, trip_id | _rest] ->
      %{
        original_trip_id: trip_id,
        route_id: route_id,
        service_id: service_id
      }
    end)
    |> Stream.chunk_every(5000)
    |> Enum.each(fn chunk ->
      Repo.insert_all(Trip, chunk, on_conflict: :replace_all, conflict_target: :original_trip_id)
    end)
  end

  def import_stop_times(file_path) do
    # 1. Preload dictionaries for ultra-fast in-memory resolution
    # In a real 1.5GB file scenario, this might need to be chunked or use an ETS table.
    # For MVP, we load maps.
    stop_dict = Repo.all(from s in Stop, select: {s.original_stop_id, s.id}) |> Map.new()
    trip_dict = Repo.all(from t in Trip, select: {t.original_trip_id, t.id}) |> Map.new()

    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn [trip_id_str, arrival_time, departure_time, stop_id_str, stop_sequence | _rest] ->
      trip_id_int = Map.get(trip_dict, trip_id_str)
      stop_id_int = Map.get(stop_dict, stop_id_str)

      # Only process if both foreign keys exist in our DB
      if trip_id_int && stop_id_int do
        %{
          trip_id: trip_id_int,
          arrival_time: parse_time(arrival_time),
          departure_time: parse_time(departure_time),
          stop_id: stop_id_int,
          stop_sequence: String.to_integer(stop_sequence)
        }
      else
        nil
      end
    end)
    |> Stream.reject(&is_nil/1)
    |> Stream.chunk_every(10_000)
    |> Enum.each(fn chunk ->
      Repo.insert_all(StopTime, chunk, on_conflict: :nothing)
    end)
  end

  defp parse_time(time_str) do
    [h, m, s] = String.split(time_str, ":") |> Enum.map(&String.to_integer/1)
    h * 3600 + m * 60 + s
  end
end
