defmodule HexaPlanner.TopologyNifTest do
  use ExUnit.Case

  test "can build rust topological graph via NIF" do
    # Edges: {StationA, StationB, Distance_km}
    edges = [
      {"8507000", "8503000", 120.5},
      {"8501008", "8507000", 160.0}
    ]

    # Should return the number of nodes built in Rust
    assert HexaPlanner.SolverNif.build_network_graph(edges) == 3
  end
end
