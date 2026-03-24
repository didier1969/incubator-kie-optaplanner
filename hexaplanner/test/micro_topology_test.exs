defmodule HexaPlanner.MicroTopologyTest do
  use ExUnit.Case
  alias HexaPlanner.SolverNif

  test "scénario D : routing via un aiguillage sans traverser les bâtiments (Zurich HB mock)" do
    resource = SolverNif.init_network()

    alias HexaPlanner.Domain.{OsmNode, OsmWay}

    # On charge des noeuds OSM simulés (liste structurée)
    nodes = [
      %OsmNode{id: 1, lon: 8.539, lat: 47.378}, # Entrée gare
      %OsmNode{id: 2, lon: 8.540, lat: 47.378}, # Aiguillage
      %OsmNode{id: 3, lon: 8.541, lat: 47.379}, # Quai 1
      %OsmNode{id: 4, lon: 8.541, lat: 47.377}, # Quai 2
      %OsmNode{id: 5, lon: 8.540, lat: 47.379}  # Bâtiment (non routable)
    ]

    ways = [
      %OsmWay{id: 101, nodes: [1, 2], tags: %{"railway" => "rail"}},
      %OsmWay{id: 102, nodes: [2, 3], tags: %{"railway" => "rail"}}, # Voie vers Quai 1
      %OsmWay{id: 103, nodes: [2, 4], tags: %{"railway" => "rail", "service" => "siding"}} # Voie vers Quai 2
    ]

    count_ways = SolverNif.load_osm(resource, nodes, ways)
    assert count_ways == 3

    # On demande un chemin (pathfinding A*) de l'entrée au Quai 2
    path = SolverNif.route_micro_path(resource, 1, 4)

    # Le chemin doit passer par l'aiguillage, donc [1, 2, 4]
    assert path == [1, 2, 4]
  end
end
