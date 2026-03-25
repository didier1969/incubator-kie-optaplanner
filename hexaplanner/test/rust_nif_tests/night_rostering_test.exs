defmodule HexaPlanner.NightRosteringTest do
  use ExUnit.Case
  alias HexaPlanner.RailwayNif
  alias HexaPlanner.GTFS.{Stop, Trip, StopTime}

  test "Phase 15: trains sharing block_id generate a static night parking EOS" do
    resource = RailwayNif.init_network()

    stops = [
      %Stop{id: 1, original_stop_id: "8507000", stop_name: "Bern", location: %Geo.Point{coordinates: {7.4, 46.9}, srid: 4326}},
      %Stop{id: 2, original_stop_id: "8503000", stop_name: "Zurich", location: %Geo.Point{coordinates: {8.5, 47.3}, srid: 4326}}
    ]
    RailwayNif.load_stops(resource, stops)

    trips = [
      %Trip{id: 101, original_trip_id: "t1", route_id: "IC1", service_id: "W", block_id: "BLOCK_A"},
      %Trip{id: 102, original_trip_id: "t2", route_id: "IC1", service_id: "W", block_id: "BLOCK_A"}
    ]
    RailwayNif.load_trips(resource, trips)

    stop_times = [
      # Trip 1 (Evening): Bern -> Zurich
      %StopTime{trip_id: 101, arrival_time: 23 * 3600, departure_time: 23 * 3600 + 60, stop_id: 1, stop_sequence: 1},
      %StopTime{trip_id: 101, arrival_time: 24 * 3600, departure_time: 24 * 3600 + 60, stop_id: 2, stop_sequence: 2},

      # Trip 2 (Next Morning): Zurich -> Bern
      %StopTime{trip_id: 102, arrival_time: 6 * 3600, departure_time: 6 * 3600 + 60, stop_id: 2, stop_sequence: 1},
      %StopTime{trip_id: 102, arrival_time: 7 * 3600, departure_time: 7 * 3600 + 60, stop_id: 1, stop_sequence: 2}
    ]
    RailwayNif.load_stop_times(resource, stop_times)

    RailwayNif.finalize_temporal_graph(resource)

    # We expect a parking EOS to be generated at Zurich between Midnight (Trip 1 End) and 6AM (Trip 2 Start)
    # Let's query the conflicts. A dummy train trying to use Zurich at 3AM should conflict with the parked train.
    
    dummy_trip = [
      %Trip{id: 999, original_trip_id: "t_dummy", route_id: "IC2", service_id: "W"}
    ]
    RailwayNif.load_trips(resource, dummy_trip)
    
    # Dummy train arriving at Zurich at 3 AM exactly where the block_id is parked
    dummy_stop_times = [
       %StopTime{trip_id: 999, arrival_time: 3 * 3600, departure_time: 3 * 3600 + 60, stop_id: 2, stop_sequence: 1},
       %StopTime{trip_id: 999, arrival_time: 4 * 3600, departure_time: 4 * 3600 + 60, stop_id: 1, stop_sequence: 2}
    ]
    RailwayNif.load_stop_times(resource, dummy_stop_times)
    
    # Finalize again to include dummy
    RailwayNif.finalize_temporal_graph(resource)
    
    conflicts = RailwayNif.get_conflict_summary(resource)
    # Right now, since logic is not implemented, total_conflicts should be 0 because 
    # train 1 ends at 24:00 and train dummy arrives at 03:00, no overlap.
    # The test demands total_conflicts > 0 which will FAIL (Red Phase).
    assert conflicts.total_conflicts > 0
  end
end
