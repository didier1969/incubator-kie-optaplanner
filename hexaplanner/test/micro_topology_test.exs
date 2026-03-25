defmodule HexaPlanner.MicroTopologyTest do
  use ExUnit.Case
  alias HexaPlanner.RailwayNif

  test "scénario D : routing via un aiguillage sans traverser les bâtiments (Zurich HB mock)" do
    resource = RailwayNif.init_network()

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

    count_ways = RailwayNif.load_osm(resource, nodes, ways)
    assert count_ways == 3

    # On demande un chemin (pathfinding A*) de l'entrée au Quai 2
    path = RailwayNif.route_micro_path(resource, 1, 4)

    # Le chemin doit passer par l'aiguillage, donc [1, 2, 4]
    assert path == [1, 2, 4]
  end

  test "Scénario C : Tag-based weighting évite une voie de garage (siding) si une voie principale est dispo" do
    resource = RailwayNif.init_network()
    alias HexaPlanner.Domain.{OsmNode, OsmWay}

    # Point de départ
    n1 = %OsmNode{id: 1, lon: 8.530, lat: 47.370}
    # Point de fin
    n4 = %OsmNode{id: 4, lon: 8.530, lat: 47.380}
    
    # Voie 1 : Courte, directe, mais "siding"
    n2 = %OsmNode{id: 2, lon: 8.530, lat: 47.375} 
    
    # Voie 2 : Un long détour géographique, mais voie principale (main line)
    n3 = %OsmNode{id: 3, lon: 8.540, lat: 47.375}
    
    # Dummy node to give n3 degree 3, so it doesn't get collapsed
    n99 = %OsmNode{id: 99, lon: 8.550, lat: 47.375}

    nodes = [n1, n2, n3, n4, n99]

    ways = [
      %OsmWay{id: 101, nodes: [1, 2, 4], tags: %{"railway" => "rail", "service" => "siding"}},
      %OsmWay{id: 102, nodes: [1, 3, 4], tags: %{"railway" => "rail"}},
      %OsmWay{id: 103, nodes: [3, 99], tags: %{"railway" => "rail"}} # Empêche le collapse de n3
    ]

    RailwayNif.load_osm(resource, nodes, ways)
    path = RailwayNif.route_micro_path(resource, 1, 4)

    # Grâce au multiplicateur x5 du siding, il doit préférer le grand détour (1 -> 3 -> 4)
    assert path == [1, 3, 4]
  end
end
