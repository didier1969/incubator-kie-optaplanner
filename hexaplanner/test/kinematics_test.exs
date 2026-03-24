defmodule HexaPlanner.KinematicsTest do
  use ExUnit.Case
  alias HexaPlanner.SolverNif
  alias HexaPlanner.Domain.{OsmNode, OsmWay}
  alias HexaPlanner.Fleet.RollingStockProfile

  test "Phase 5: Heavy freight train takes longer to route via switches than light passenger train" do
    resource = SolverNif.init_network()

    # Load Fleet Profiles
    freight_profile = %RollingStockProfile{model: "freight", mass_tonnes: 2000.0, acceleration_ms2: 0.3, max_speed_kmh: 100.0, length_meters: 500.0}
    tgv_profile = %RollingStockProfile{model: "passenger", mass_tonnes: 400.0, acceleration_ms2: 1.2, max_speed_kmh: 300.0, length_meters: 200.0}
    
    SolverNif.load_fleet(resource, %{1 => freight_profile, 2 => tgv_profile})

    # Load simple switch topology
    n1 = %OsmNode{id: 1, lon: 8.530, lat: 47.370}
    n2 = %OsmNode{id: 2, lon: 8.535, lat: 47.370} # Aiguillage
    n3 = %OsmNode{id: 3, lon: 8.540, lat: 47.370}

    nodes = [n1, n2, n3]

    ways = [
      %OsmWay{id: 101, nodes: [1, 2], tags: %{"railway" => "rail"}},
      %OsmWay{id: 102, nodes: [2, 3], tags: %{"railway" => "switch"}}
    ]

    SolverNif.load_osm(resource, nodes, ways)

    # Route both trains through the switch
    {freight_path, freight_time} = SolverNif.route_micro_path_with_kinematics(resource, 1, 3, 1)
    {tgv_path, tgv_time} = SolverNif.route_micro_path_with_kinematics(resource, 1, 3, 2)

    assert freight_path == [1, 2, 3]
    assert tgv_path == [1, 2, 3]

    # The heavy freight train should take significantly longer to accelerate and brake through the switch
    assert freight_time > tgv_time * 1.5
  end
end
