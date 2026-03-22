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
    stops_table = :ets.new(:stops_dict, [:set, :public, read_concurrency: true])
    trips_table = :ets.new(:trips_dict, [:set, :public, read_concurrency: true])

    Repo.all(from(s in Stop, select: {s.original_stop_id, s.id}))
    |> Enum.each(fn {orig, id} -> :ets.insert(stops_table, {orig, id}) end)

    Repo.all(from(t in Trip, select: {t.original_trip_id, t.id}))
    |> Enum.each(fn {orig, id} -> :ets.insert(trips_table, {orig, id}) end)

    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn [
                       trip_id_str,
                       arrival_time,
                       departure_time,
                       stop_id_str,
                       stop_sequence | _rest
                     ] ->
      trip_id_int = case :ets.lookup(trips_table, trip_id_str) do
        [{_, id}] -> id
        [] -> nil
      end

      stop_id_int = case :ets.lookup(stops_table, stop_id_str) do
        [{_, id}] -> id
        [] -> nil
      end

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

    :ets.delete(stops_table)
    :ets.delete(trips_table)
  end

  defp parse_time(time_str) do
    [h, m, s] = String.split(time_str, ":") |> Enum.map(&String.to_integer/1)
    h * 3600 + m * 60 + s
  end
end
