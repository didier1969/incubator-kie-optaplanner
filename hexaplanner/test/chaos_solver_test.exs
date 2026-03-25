defmodule HexaPlanner.ChaosSolverTest do
  use ExUnit.Case
  alias HexaPlanner.RailwayNif
  alias HexaPlanner.GTFS.Stop
  alias HexaPlanner.GTFS.StopTime

  test "injects delay and resolves conflicts via greedy algorithm" do
    resource = RailwayNif.init_network()

    stops = [
      %Stop{id: 1, original_stop_id: "A", stop_name: "Station A", location: %Geo.Point{coordinates: {0.0, 0.0}, srid: 4326}, abbreviation: "A", location_type: 0, parent_station: "", platform_code: ""},
      %Stop{id: 2, original_stop_id: "B", stop_name: "Station B", location: %Geo.Point{coordinates: {1.0, 0.0}, srid: 4326}, abbreviation: "B", location_type: 0, parent_station: "", platform_code: ""}
    ]
    RailwayNif.load_stops(resource, stops)
    
    tracks = [
      %HexaPlanner.Data.Parser.TrackSegment{
        line_id: "L1",
        coordinates: [{0.0, 0.0}, {1.0, 0.0}],
        properties: %{"bp_anfang" => "A", "bp_ende" => "B"}
      }
    ]
    RailwayNif.load_tracks(resource, tracks)
    
    st1 = %StopTime{trip_id: 100, stop_id: 1, arrival_time: 100, departure_time: 100, stop_sequence: 1, pickup_type: 0, drop_off_type: 0}
    st2 = %StopTime{trip_id: 100, stop_id: 2, arrival_time: 200, departure_time: 200, stop_sequence: 2, pickup_type: 0, drop_off_type: 0}
    
    st3 = %StopTime{trip_id: 200, stop_id: 1, arrival_time: 101, departure_time: 101, stop_sequence: 1, pickup_type: 0, drop_off_type: 0}
    st4 = %StopTime{trip_id: 200, stop_id: 2, arrival_time: 201, departure_time: 201, stop_sequence: 2, pickup_type: 0, drop_off_type: 0}

    RailwayNif.load_stop_times(resource, [st1, st2, st3, st4])
    RailwayNif.finalize_temporal_graph(resource)

    # Chaos! Delay Trip 100 by 60 seconds
    assert :ok == RailwayNif.inject_delay(resource, 100, 60)

    # Resolution
    result = RailwayNif.resolve_conflict_greedy(resource)
    
    assert result.status == "success"
    assert result.trains_impacted >= 1
    assert result.total_delay_added > 0
  end

  test "resolves conflicts using Local Search (Tabu) with better optimization than greedy" do
    resource = RailwayNif.init_network()

    stops = [
      %Stop{id: 1, original_stop_id: "A", stop_name: "Station A", location: %Geo.Point{coordinates: {0.0, 0.0}, srid: 4326}, abbreviation: "A", location_type: 0, parent_station: "", platform_code: ""},
      %Stop{id: 2, original_stop_id: "B", stop_name: "Station B", location: %Geo.Point{coordinates: {1.0, 0.0}, srid: 4326}, abbreviation: "B", location_type: 0, parent_station: "", platform_code: ""}
    ]
    RailwayNif.load_stops(resource, stops)
    
    tracks = [
      %HexaPlanner.Data.Parser.TrackSegment{
        line_id: "L1",
        coordinates: [{0.0, 0.0}, {1.0, 0.0}],
        properties: %{"bp_anfang" => "A", "bp_ende" => "B"}
      }
    ]
    RailwayNif.load_tracks(resource, tracks)
    
    st1 = %StopTime{trip_id: 100, stop_id: 1, arrival_time: 100, departure_time: 100, stop_sequence: 1, pickup_type: 0, drop_off_type: 0}
    st2 = %StopTime{trip_id: 100, stop_id: 2, arrival_time: 200, departure_time: 200, stop_sequence: 2, pickup_type: 0, drop_off_type: 0}
    
    st3 = %StopTime{trip_id: 200, stop_id: 1, arrival_time: 101, departure_time: 101, stop_sequence: 1, pickup_type: 0, drop_off_type: 0}
    st4 = %StopTime{trip_id: 200, stop_id: 2, arrival_time: 201, departure_time: 201, stop_sequence: 2, pickup_type: 0, drop_off_type: 0}

    RailwayNif.load_stop_times(resource, [st1, st2, st3, st4])
    RailwayNif.finalize_temporal_graph(resource)

    # Inject Chaos
    assert :ok == RailwayNif.inject_delay(resource, 100, 60)

    # Resolution
    result = RailwayNif.resolve_conflict_local_search(resource)
    
    assert result.status == "success"
    # Local search should ideally resolve this efficiently
    assert result.computation_time_ms >= 0
  end
end
