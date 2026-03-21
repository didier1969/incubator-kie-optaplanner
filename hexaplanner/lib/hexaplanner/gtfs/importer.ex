defmodule HexaPlanner.GTFS.Importer do
  @moduledoc """
  Handles the streaming and bulk ingestion of GTFS static files
  into the PostgreSQL database.
  """
  alias HexaPlanner.GTFS.Stop
  alias HexaPlanner.GTFS.StopTime
  alias HexaPlanner.GTFS.Trip
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

  def import_trips(file_path) do
    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn [route_id, service_id, trip_id | _rest] ->
      %{
        trip_id: trip_id,
        route_id: route_id,
        service_id: service_id
      }
    end)
    |> Stream.chunk_every(5000)
    |> Enum.each(fn chunk ->
      Repo.insert_all(Trip, chunk, on_conflict: :replace_all, conflict_target: :trip_id)
    end)
  end

  def import_stop_times(file_path) do
    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn [trip_id, arrival_time, departure_time, stop_id, stop_sequence | _rest] ->
      %{
        trip_id: trip_id,
        arrival_time: parse_time(arrival_time),
        departure_time: parse_time(departure_time),
        stop_id: stop_id,
        stop_sequence: String.to_integer(stop_sequence)
      }
    end)
    |> Stream.chunk_every(10_000)
    |> Enum.each(fn chunk ->
      Repo.insert_all(StopTime, chunk, on_conflict: :nothing)
    end)
  end

  defp parse_time(time_str) do
    # GTFS time format: HH:MM:SS (can be >= 24 for overnight trips)
    [h, m, s] = String.split(time_str, ":") |> Enum.map(&String.to_integer/1)
    h * 3600 + m * 60 + s
  end
end
