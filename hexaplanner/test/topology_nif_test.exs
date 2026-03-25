defmodule HexaPlanner.TopologyNifTest do
  use ExUnit.Case
  alias HexaPlanner.RailwayNif
  alias HexaPlanner.GTFS.Stop

  test "can initialize a network resource and load stops into rust" do
    resource = RailwayNif.init_network()
    assert is_reference(resource)

    stops = [
      %Stop{id: 1, original_stop_id: "8507000", stop_name: "Bern", abbreviation: "BN", location: %Geo.Point{coordinates: {7.4, 46.9}}},
      %Stop{id: 2, original_stop_id: "8503000", stop_name: "Zürich HB", abbreviation: "ZUE", location: %Geo.Point{coordinates: {8.5, 47.3}}}
    ]

    count = RailwayNif.load_stops(resource, stops)
    assert count == 2
  end

  test "can load stop times and create temporal edges in rust" do
    resource = RailwayNif.init_network()

    # Need stops first
    stops = [
      %Stop{id: 1, original_stop_id: "8507000", stop_name: "Bern", abbreviation: "BN", location: %Geo.Point{coordinates: {7.4, 46.9}}},
      %Stop{id: 2, original_stop_id: "8503000", stop_name: "Zürich HB", abbreviation: "ZUE", location: %Geo.Point{coordinates: {8.5, 47.3}}}
    ]

    RailwayNif.load_stops(resource, stops)

    alias HexaPlanner.GTFS.StopTime

    stop_times = [
      %StopTime{
        trip_id: 100,
        stop_id: 1,
        arrival_time: 36000,
        departure_time: 36060,
        stop_sequence: 1,
        pickup_type: 0,
        drop_off_type: 0
      },
      %StopTime{
        trip_id: 100,
        stop_id: 2,
        arrival_time: 39600,
        departure_time: 39660,
        stop_sequence: 2,
        pickup_type: 0,
        drop_off_type: 0
      }
    ]

    edge_count = RailwayNif.load_stop_times(resource, stop_times)
    assert edge_count == 0 # As load_stop_times just loads them into the manager, graph is built in finalize_temporal_graph
  end

  test "can load track segments into rust" do
    resource = RailwayNif.init_network()

    alias HexaPlanner.Data.Parser.TrackSegment

    tracks = [
      %TrackSegment{line_id: "100", coordinates: [{7.4, 46.9}, {7.45, 46.95}, {7.5, 47.0}]}
    ]

    _count = RailwayNif.load_tracks(resource, tracks)
    assert true
  end

  test "can interpolate train position between stops in rust" do
    resource = RailwayNif.init_network()

    # Setup network
    stops = [
      %Stop{id: 1, original_stop_id: "8507000", stop_name: "Bern", abbreviation: "BN", location: %Geo.Point{coordinates: {7.4, 46.9}}},
      %Stop{id: 2, original_stop_id: "8503000", stop_name: "Zürich HB", abbreviation: "ZUE", location: %Geo.Point{coordinates: {8.5, 47.3}}}
    ]

    RailwayNif.load_stops(resource, stops)

    alias HexaPlanner.GTFS.StopTime

    stop_times = [
      %StopTime{
        trip_id: 100,
        stop_id: 1,
        arrival_time: 36000,
        departure_time: 36000,
        stop_sequence: 1,
        pickup_type: 0,
        drop_off_type: 0
      },
      %StopTime{
        trip_id: 100,
        stop_id: 2,
        arrival_time: 37000,
        departure_time: 37000,
        stop_sequence: 2,
        pickup_type: 0,
        drop_off_type: 0
      }
    ]

    RailwayNif.load_stop_times(resource, stop_times)

    # Query middle position (t=36500)
    {lon, lat} = RailwayNif.get_train_position(resource, 100, 36500)

    # Expected middle point
    assert_in_delta lon, 7.95, 0.01
    assert_in_delta lat, 47.1, 0.01
  end
end
