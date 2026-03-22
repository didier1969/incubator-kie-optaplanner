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
    # 1. Sync dictionaries to PostgreSQL unlogged tables for ultra-fast, zero-memory SQL JOINs
    Repo.query!("TRUNCATE TABLE gtfs_stops_dict")
    Repo.query!("TRUNCATE TABLE gtfs_trips_dict")
    
    Repo.query!("INSERT INTO gtfs_stops_dict (original_id, id) SELECT original_stop_id, id FROM gtfs_stops")
    Repo.query!("INSERT INTO gtfs_trips_dict (original_id, id) SELECT original_trip_id, id FROM gtfs_trips")

    # 2. Stream the file and insert into a temporary unlogged staging table
    Repo.query!("CREATE UNLOGGED TABLE IF NOT EXISTS gtfs_stop_times_staging (trip_id_str text, arrival_time int, departure_time int, stop_id_str text, stop_sequence int)")
    Repo.query!("TRUNCATE TABLE gtfs_stop_times_staging")

    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn [trip_id_str, arrival_time, departure_time, stop_id_str, stop_sequence | _rest] ->
      [
        trip_id_str,
        parse_time(arrival_time),
        parse_time(departure_time),
        stop_id_str,
        String.to_integer(stop_sequence)
      ]
    end)
    |> Stream.chunk_every(10_000)
    |> Enum.each(fn chunk ->
      # We use bare Repo.query! to bypass Ecto schema overhead for the staging table
      placeholders = Enum.map(1..5, &"$#{&1}") |> Enum.join(",")
      
      # Flatten the chunk for the parameterized query
      flat_params = List.flatten(chunk)
      
      # Build the massive INSERT statement dynamically
      values_str = chunk
                   |> Enum.with_index()
                   |> Enum.map(fn {_, idx} ->
                     offset = idx * 5
                     "($#{offset + 1}, $#{offset + 2}, $#{offset + 3}, $#{offset + 4}, $#{offset + 5})"
                   end)
                   |> Enum.join(",")

      query = "INSERT INTO gtfs_stop_times_staging (trip_id_str, arrival_time, departure_time, stop_id_str, stop_sequence) VALUES " <> values_str
      Repo.query!(query, flat_params)
    end)

    # 3. Perform the massive resolution directly inside PostgreSQL using a single query
    Repo.query!("""
      INSERT INTO gtfs_stop_times (trip_id, arrival_time, departure_time, stop_id, stop_sequence)
      SELECT t.id, s.arrival_time, s.departure_time, st.id, s.stop_sequence
      FROM gtfs_stop_times_staging s
      JOIN gtfs_trips_dict t ON s.trip_id_str = t.original_id
      JOIN gtfs_stops_dict st ON s.stop_id_str = st.original_id
      ON CONFLICT DO NOTHING
    """)

    # 4. Cleanup
    Repo.query!("TRUNCATE TABLE gtfs_stop_times_staging")
  end

  defp parse_time(time_str) do
    [h, m, s] = String.split(time_str, ":") |> Enum.map(&String.to_integer/1)
    h * 3600 + m * 60 + s
  end
end
