defmodule HexaRail.GTFS.TemporalImporterTest do
  use HexaRail.DataCase
  alias HexaRail.GTFS.Importer
  alias HexaRail.Repo

  @stops_data "stop_id,stop_name,stop_lat,stop_lon\n8507000,Bern,46.9488,7.4391\n8503000,Zürich HB,47.3779,8.5402\n"
  @trips_data "route_id,service_id,trip_id\n1,s1,TRIP_1\n"
  @stop_times_data "trip_id,arrival_time,departure_time,stop_id,stop_sequence\nTRIP_1,10:00:00,10:05:00,8507000,1\nTRIP_1,11:00:00,11:05:00,8503000,2\n"

  setup do
    stops_path = Path.join(System.tmp_dir!(), "stops_test.txt")
    trips_path = Path.join(System.tmp_dir!(), "trips_test.txt")
    stop_times_path = Path.join(System.tmp_dir!(), "stop_times_test.txt")

    File.write!(stops_path, @stops_data)
    File.write!(trips_path, @trips_data)
    File.write!(stop_times_path, @stop_times_data)

    on_exit(fn ->
      File.rm(stops_path)
      File.rm(trips_path)
      File.rm(stop_times_path)
    end)

    %{stops_path: stops_path, trips_path: trips_path, stop_times_path: stop_times_path}
  end

  test "imports trips and stop times", %{
    stops_path: stops_path,
    trips_path: trips_path,
    stop_times_path: stop_times_path
  } do
    # Must import stops first due to FK constraints
    Importer.import_stops(stops_path)
    Importer.import_trips(trips_path)
    Importer.import_stop_times(stop_times_path)

    trips = Repo.all(HexaRail.GTFS.Trip)
    assert length(trips) == 1
    assert hd(trips).original_trip_id == "TRIP_1"

    stop_times = Repo.all(HexaRail.GTFS.StopTime) |> Enum.sort_by(& &1.stop_sequence)
    assert length(stop_times) == 2
    # 10:00:00 is 36000 seconds
    assert Enum.at(stop_times, 0).arrival_time == 36_000
    assert Enum.at(stop_times, 1).arrival_time == 39_600
  end
end
