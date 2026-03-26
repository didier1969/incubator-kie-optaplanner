defmodule HexaRail.GTFS.Importer do
  @moduledoc """
  Handles the streaming and bulk ingestion of GTFS static files
  into the PostgreSQL database.
  """
  alias HexaRail.GTFS.Stop
  alias HexaRail.GTFS.Trip
  alias HexaRail.Repo

  NimbleCSV.define(GTFSParser, separator: ",", escape: "\"")

  def import_stops(file_path) do
    # Load abbreviations from GeoJSON for enrichment
    data_dir = Path.dirname(file_path)
    geojson_path = Path.join(data_dir, "../stops.geojson")

    abbreviations_map =
      if File.exists?(geojson_path) do
        geojson_path
        |> File.read!()
        |> Jason.decode!()
        |> Map.get("features")
        |> Enum.map(fn f ->
          {to_string(f["properties"]["number"]), f["properties"]["abbreviation"]}
        end)
        |> Map.new()
      else
        %{}
      end

    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn 
      [
                       stop_id,
                       stop_name,
                       stop_lat,
                       stop_lon,
                       location_type,
                       parent_station,
                       platform_code | _
                     ] ->
      lat = String.to_float(stop_lat)
      lon = String.to_float(stop_lon)
      point = %Geo.Point{coordinates: {lon, lat}, srid: 4326}

      %{
        original_stop_id: stop_id,
        stop_name: stop_name,
        abbreviation: Map.get(abbreviations_map, stop_id),
        location: point,
        location_type: parse_integer_or_null(location_type),
        parent_station: if(parent_station == "", do: nil, else: parent_station),
        platform_code: if(platform_code == "", do: nil, else: platform_code)
      }
      [stop_id, stop_name, stop_lat, stop_lon] ->
        lat = String.to_float(stop_lat)
        lon = String.to_float(stop_lon)
        point = %Geo.Point{coordinates: {lon, lat}, srid: 4326}

        %{
          original_stop_id: stop_id,
          stop_name: stop_name,
          abbreviation: Map.get(abbreviations_map, stop_id),
          location: point,
          location_type: nil,
          parent_station: nil,
          platform_code: nil
        }
    end)
    |> Stream.chunk_every(1000)
    |> Enum.each(fn chunk ->
      Repo.insert_all(Stop, chunk, on_conflict: :nothing, log: false)
      IO.write(".")
    end)

    IO.puts("")
  end

  def import_trips(file_path) do
    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn 
      [
                       route_id,
                       service_id,
                       trip_id,
                       trip_headsign,
                       trip_short_name,
                       direction_id,
                       block_id,
                       _original_trip_id,
                       hints | _rest
                     ] ->
      %{
        original_trip_id: trip_id,
        route_id: route_id,
        service_id: service_id,
        trip_headsign: if(trip_headsign == "", do: nil, else: trip_headsign),
        trip_short_name: if(trip_short_name == "", do: nil, else: trip_short_name),
        direction_id: parse_integer_or_null(direction_id),
        block_id: if(block_id == "", do: nil, else: block_id),
        hints: if(hints == "", do: nil, else: hints)
      }
      [route_id, service_id, trip_id] ->
        %{
          original_trip_id: trip_id,
          route_id: route_id,
          service_id: service_id,
          trip_headsign: nil,
          trip_short_name: nil,
          direction_id: nil,
          block_id: nil,
          hints: nil
        }
    end)
    |> Stream.chunk_every(5000)
    |> Enum.each(fn chunk ->
      Repo.insert_all(Trip, chunk,
        on_conflict: :nothing,
        log: false
      )

      IO.write(".")
    end)

    IO.puts("")
  end

  def import_stop_times(file_path) do
    # 1. Sync dictionaries to PostgreSQL unlogged tables for ultra-fast, zero-memory SQL JOINs
    Repo.query!("TRUNCATE TABLE gtfs_stops_dict", [], log: false)
    Repo.query!("TRUNCATE TABLE gtfs_trips_dict", [], log: false)

    Repo.query!(
      "INSERT INTO gtfs_stops_dict (original_id, id) SELECT original_stop_id, id FROM gtfs_stops",
      [],
      log: false
    )

    Repo.query!(
      "INSERT INTO gtfs_trips_dict (original_id, id) SELECT original_trip_id, id FROM gtfs_trips",
      [],
      log: false
    )

    # 2. Stream the file and insert into a temporary unlogged staging table
    Repo.query!("DROP TABLE IF EXISTS gtfs_stop_times_staging", [], log: false)

    Repo.query!(
      "CREATE UNLOGGED TABLE gtfs_stop_times_staging (trip_id_str text, arrival_time int, departure_time int, stop_id_str text, stop_sequence int, pickup_type int, drop_off_type int)",
      [],
      log: false
    )

    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn 
      [
                       trip_id_str,
                       arrival_time,
                       departure_time,
                       stop_id_str,
                       stop_sequence,
                       pickup_type,
                       drop_off_type | _rest
                     ] ->
      [
        trip_id_str,
        parse_time(arrival_time),
        parse_time(departure_time),
        stop_id_str,
        String.to_integer(stop_sequence),
        parse_integer_or_null(pickup_type),
        parse_integer_or_null(drop_off_type)
      ]
      [trip_id_str, arrival_time, departure_time, stop_id_str, stop_sequence] ->
        [
          trip_id_str,
          parse_time(arrival_time),
          parse_time(departure_time),
          stop_id_str,
          String.to_integer(stop_sequence),
          nil,
          nil
        ]
    end)
    # 8000 * 7 = 56000 < 65535 limit
    |> Stream.chunk_every(8000)
    |> Enum.each(fn chunk ->
      # Build the massive INSERT statement dynamically
      values_str =
        chunk
        |> Enum.with_index()
        |> Enum.map(fn {_, idx} ->
          offset = idx * 7

          "($#{offset + 1}, $#{offset + 2}, $#{offset + 3}, $#{offset + 4}, $#{offset + 5}, $#{offset + 6}, $#{offset + 7})"
        end)
        |> Enum.join(",")

      query =
        "INSERT INTO gtfs_stop_times_staging (trip_id_str, arrival_time, departure_time, stop_id_str, stop_sequence, pickup_type, drop_off_type) VALUES " <>
          values_str

      flat_params = List.flatten(chunk)
      Repo.query!(query, flat_params, log: false)
      IO.write(".")
    end)

    IO.puts("\nResolving IDs in PostgreSQL...")

    # 3. Perform the massive resolution directly inside PostgreSQL using a single query
    Repo.query!(
      """
        INSERT INTO gtfs_stop_times (trip_id, arrival_time, departure_time, stop_id, stop_sequence, pickup_type, drop_off_type)
        SELECT t.id, s.arrival_time, s.departure_time, st.id, s.stop_sequence, s.pickup_type, s.drop_off_type
        FROM gtfs_stop_times_staging s
        JOIN gtfs_trips_dict t ON s.trip_id_str = t.original_id
        JOIN gtfs_stops_dict st ON s.stop_id_str = st.original_id
        ON CONFLICT DO NOTHING
      """,
      [],
      timeout: :infinity,
      log: false
    )

    # 4. Cleanup
    Repo.query!("DROP TABLE IF EXISTS gtfs_stop_times_staging", [], log: false)
    IO.puts("Done.")
  end

  def import_transfers(file_path) do
    Repo.query!("DROP TABLE IF EXISTS gtfs_transfers_staging", [], log: false)

    Repo.query!(
      "CREATE UNLOGGED TABLE gtfs_transfers_staging (from_stop_id_str text, to_stop_id_str text, transfer_type int, min_transfer_time int, from_trip_id_str text, to_trip_id_str text, from_route_id_str text, to_route_id_str text)",
      [],
      log: false
    )

    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn [
                       from_stop_id_str,
                       to_stop_id_str,
                       from_route_id,
                       to_route_id,
                       from_trip_id_str,
                       to_trip_id_str,
                       transfer_type,
                       min_transfer_time | _rest
                     ] ->
      [
        from_stop_id_str,
        to_stop_id_str,
        parse_integer_or_null(transfer_type),
        parse_integer_or_null(min_transfer_time),
        if(from_trip_id_str == "", do: nil, else: from_trip_id_str),
        if(to_trip_id_str == "", do: nil, else: to_trip_id_str),
        if(from_route_id == "", do: nil, else: from_route_id),
        if(to_route_id == "", do: nil, else: to_route_id)
      ]
    end)
    # 8000 * 8 = 56000 < 65535 limit
    |> Stream.chunk_every(8000)
    |> Enum.each(fn chunk ->
      flat_params = List.flatten(chunk)

      values_str =
        chunk
        |> Enum.with_index()
        |> Enum.map(fn {_, idx} ->
          offset = idx * 8

          "($#{offset + 1}, $#{offset + 2}, $#{offset + 3}, $#{offset + 4}, $#{offset + 5}, $#{offset + 6}, $#{offset + 7}, $#{offset + 8})"
        end)
        |> Enum.join(",")

      query =
        "INSERT INTO gtfs_transfers_staging (from_stop_id_str, to_stop_id_str, transfer_type, min_transfer_time, from_trip_id_str, to_trip_id_str, from_route_id_str, to_route_id_str) VALUES " <>
          values_str

      Repo.query!(query, flat_params, log: false)
      IO.write(".")
    end)

    # Resolve foreign keys via SQL and inject smart defaults for waiting_tolerance_seconds
    Repo.query!(
      """
        INSERT INTO gtfs_transfers (from_stop_id, to_stop_id, transfer_type, min_transfer_time, waiting_tolerance_seconds, from_trip_id, to_trip_id, from_route_id, to_route_id)
        SELECT
          st_from.id,
          st_to.id,
          s.transfer_type,
          s.min_transfer_time,
          CASE 
            WHEN r_to.route_type IN (0, 1, 2, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 900) THEN 120 -- Train waits 2 mins
            WHEN r_to.route_type IN (3, 700, 701, 702, 703, 704, 705, 715) THEN 300 -- Bus waits 5 mins
            ELSE 0
          END as waiting_tolerance_seconds,
          tr_from.id,
          tr_to.id,
          r_from.id,
          r_to.id
        FROM gtfs_transfers_staging s
        JOIN gtfs_stops_dict st_from ON s.from_stop_id_str = st_from.original_id
        JOIN gtfs_stops_dict st_to ON s.to_stop_id_str = st_to.original_id
        LEFT JOIN gtfs_trips_dict tr_from ON s.from_trip_id_str = tr_from.original_id
        LEFT JOIN gtfs_trips_dict tr_to ON s.to_trip_id_str = tr_to.original_id
        LEFT JOIN gtfs_routes r_from ON s.from_route_id_str = r_from.original_route_id
        LEFT JOIN gtfs_routes r_to ON s.to_route_id_str = r_to.original_route_id
        ON CONFLICT DO NOTHING
      """,
      [],
      timeout: :infinity,
      log: false
    )

    Repo.query!("DROP TABLE IF EXISTS gtfs_transfers_staging", [], log: false)
    IO.puts("")
  end

  def import_calendars(file_path) do
    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn [
                       service_id,
                       monday,
                       tuesday,
                       wednesday,
                       thursday,
                       friday,
                       saturday,
                       sunday,
                       start_date,
                       end_date | _rest
                     ] ->
      [
        service_id,
        String.to_integer(monday),
        String.to_integer(tuesday),
        String.to_integer(wednesday),
        String.to_integer(thursday),
        String.to_integer(friday),
        String.to_integer(saturday),
        String.to_integer(sunday),
        String.to_integer(start_date),
        String.to_integer(end_date)
      ]
    end)
    # 5000 * 10 = 50000 < 65535 limit
    |> Stream.chunk_every(5000)
    |> Enum.each(fn chunk ->
      flat_params = List.flatten(chunk)

      values_str =
        chunk
        |> Enum.with_index()
        |> Enum.map(fn {_, idx} ->
          offset = idx * 10

          "($#{offset + 1}, $#{offset + 2}, $#{offset + 3}, $#{offset + 4}, $#{offset + 5}, $#{offset + 6}, $#{offset + 7}, $#{offset + 8}, $#{offset + 9}, $#{offset + 10})"
        end)
        |> Enum.join(",")

      query =
        "INSERT INTO gtfs_calendars (service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date) VALUES " <>
          values_str <> " ON CONFLICT (service_id) DO NOTHING"

      Repo.query!(query, flat_params, log: false)
      IO.write(".")
    end)

    IO.puts("")
  end

  def import_calendar_dates(file_path) do
    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn [service_id, date, exception_type | _rest] ->
      [
        service_id,
        String.to_integer(date),
        String.to_integer(exception_type)
      ]
    end)
    # 10000 * 3 = 30000 < 65535 limit
    |> Stream.chunk_every(10_000)
    |> Enum.each(fn chunk ->
      flat_params = List.flatten(chunk)

      values_str =
        chunk
        |> Enum.with_index()
        |> Enum.map(fn {_, idx} ->
          offset = idx * 3
          "($#{offset + 1}, $#{offset + 2}, $#{offset + 3})"
        end)
        |> Enum.join(",")

      query =
        "INSERT INTO gtfs_calendar_dates (service_id, date, exception_type) VALUES " <> values_str

      Repo.query!(query, flat_params, log: false)
      IO.write(".")
    end)

    IO.puts("")
  end

  def import_agency(file_path) do
    Repo.query!("DROP TABLE IF EXISTS gtfs_agency_staging", [], log: false)

    Repo.query!(
      "CREATE UNLOGGED TABLE gtfs_agency_staging (original_agency_id text, agency_name text, agency_url text, agency_timezone text, agency_lang text, agency_phone text)",
      [],
      log: false
    )

    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn [
                       original_agency_id,
                       agency_name,
                       agency_url,
                       agency_timezone,
                       agency_lang,
                       agency_phone | _rest
                     ] ->
      [
        original_agency_id,
        agency_name,
        agency_url,
        agency_timezone,
        agency_lang,
        agency_phone
      ]
    end)
    |> Stream.chunk_every(10_000)
    |> Enum.each(fn chunk ->
      flat_params = List.flatten(chunk)

      values_str =
        chunk
        |> Enum.with_index()
        |> Enum.map(fn {_, idx} ->
          offset = idx * 6

          "($#{offset + 1}, $#{offset + 2}, $#{offset + 3}, $#{offset + 4}, $#{offset + 5}, $#{offset + 6})"
        end)
        |> Enum.join(",")

      query =
        "INSERT INTO gtfs_agency_staging (original_agency_id, agency_name, agency_url, agency_timezone, agency_lang, agency_phone) VALUES " <>
          values_str

      Repo.query!(query, flat_params, log: false)
      IO.write(".")
    end)

    Repo.query!(
      """
        INSERT INTO gtfs_agency (original_agency_id, agency_name, agency_url, agency_timezone, agency_lang, agency_phone)
        SELECT original_agency_id, agency_name, agency_url, agency_timezone, agency_lang, agency_phone
        FROM gtfs_agency_staging
        ON CONFLICT DO NOTHING
      """,
      [],
      log: false
    )

    Repo.query!("DROP TABLE IF EXISTS gtfs_agency_staging", [], log: false)
    IO.puts("")
  end

  def import_routes(file_path) do
    Repo.query!("DROP TABLE IF EXISTS gtfs_routes_staging", [], log: false)

    Repo.query!(
      "CREATE UNLOGGED TABLE gtfs_routes_staging (original_route_id text, agency_id_str text, route_short_name text, route_long_name text, route_desc text, route_type int)",
      [],
      log: false
    )

    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn [
                       original_route_id,
                       agency_id_str,
                       route_short_name,
                       route_long_name,
                       route_desc,
                       route_type | _rest
                     ] ->
      [
        original_route_id,
        agency_id_str,
        route_short_name,
        route_long_name,
        route_desc,
        parse_integer_or_null(route_type)
      ]
    end)
    |> Stream.chunk_every(10_000)
    |> Enum.each(fn chunk ->
      flat_params = List.flatten(chunk)

      values_str =
        chunk
        |> Enum.with_index()
        |> Enum.map(fn {_, idx} ->
          offset = idx * 6

          "($#{offset + 1}, $#{offset + 2}, $#{offset + 3}, $#{offset + 4}, $#{offset + 5}, $#{offset + 6})"
        end)
        |> Enum.join(",")

      query =
        "INSERT INTO gtfs_routes_staging (original_route_id, agency_id_str, route_short_name, route_long_name, route_desc, route_type) VALUES " <>
          values_str

      Repo.query!(query, flat_params, log: false)
      IO.write(".")
    end)

    Repo.query!(
      """
        INSERT INTO gtfs_routes (original_route_id, agency_id, route_short_name, route_long_name, route_desc, route_type)
        SELECT
          s.original_route_id,
          a.id,
          s.route_short_name,
          s.route_long_name,
          s.route_desc,
          s.route_type
        FROM gtfs_routes_staging s
        LEFT JOIN gtfs_agency a ON s.agency_id_str = a.original_agency_id
        ON CONFLICT DO NOTHING
      """,
      [],
      log: false
    )

    Repo.query!("DROP TABLE IF EXISTS gtfs_routes_staging", [], log: false)
    IO.puts("")
  end

  def import_frequencies(file_path) do
    Repo.query!("DROP TABLE IF EXISTS gtfs_frequencies_staging", [], log: false)

    Repo.query!(
      "CREATE UNLOGGED TABLE gtfs_frequencies_staging (trip_id_str text, start_time int, end_time int, headway_secs int, exact_times int)",
      [],
      log: false
    )

    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Stream.map(fn [trip_id_str, start_time, end_time, headway_secs, exact_times | _rest] ->
      [
        trip_id_str,
        parse_time(start_time),
        parse_time(end_time),
        parse_integer_or_null(headway_secs),
        parse_integer_or_null(exact_times)
      ]
    end)
    |> Stream.chunk_every(10_000)
    |> Enum.each(fn chunk ->
      flat_params = List.flatten(chunk)

      values_str =
        chunk
        |> Enum.with_index()
        |> Enum.map(fn {_, idx} ->
          offset = idx * 5
          "($#{offset + 1}, $#{offset + 2}, $#{offset + 3}, $#{offset + 4}, $#{offset + 5})"
        end)
        |> Enum.join(",")

      query =
        "INSERT INTO gtfs_frequencies_staging (trip_id_str, start_time, end_time, headway_secs, exact_times) VALUES " <>
          values_str

      Repo.query!(query, flat_params, log: false)
      IO.write(".")
    end)

    Repo.query!(
      """
        INSERT INTO gtfs_frequencies (trip_id, start_time, end_time, headway_secs, exact_times)
        SELECT
          t.id,
          s.start_time,
          s.end_time,
          s.headway_secs,
          s.exact_times
        FROM gtfs_frequencies_staging s
        JOIN gtfs_trips t ON s.trip_id_str = t.original_trip_id
        ON CONFLICT DO NOTHING
      """,
      [],
      log: false
    )

    Repo.query!("DROP TABLE IF EXISTS gtfs_frequencies_staging", [], log: false)
    IO.puts("")
  end

  def import_feed_info(file_path) do
    file_path
    |> File.stream!()
    |> GTFSParser.parse_stream()
    |> Enum.each(fn [publisher_name, publisher_url, lang, start_date, end_date, version | _rest] ->
      query = """
        INSERT INTO gtfs_feed_info (feed_publisher_name, feed_publisher_url, feed_lang, feed_start_date, feed_end_date, feed_version)
        VALUES ($1, $2, $3, $4, $5, $6)
      """

      Repo.query!(
        query,
        [
          publisher_name,
          publisher_url,
          lang,
          parse_integer_or_null(start_date),
          parse_integer_or_null(end_date),
          version
        ],
        log: false
      )
    end)
  end

  defp parse_integer_or_null(""), do: nil
  defp parse_integer_or_null(val), do: String.to_integer(val)

  defp parse_time(time_str) do
    [h, m, s] = String.split(time_str, ":") |> Enum.map(&String.to_integer/1)
    h * 3600 + m * 60 + s
  end
end
