defmodule HexaPlanner.Data.OsmParser do
  @moduledoc """
  Parses OpenStreetMap JSON data (from Overpass) into Elixir structs
  compatible with the Rust Data Plane (OsmNode, OsmWay).
  """

  defmodule OsmNode do
    defstruct [:id, :lat, :lon, tags: %{}]
  end

  defmodule OsmWay do
    defstruct [:id, nodes: [], tags: %{}]
  end

  def parse_file(filepath) do
    data = 
      filepath
      |> File.read!()
      |> Jason.decode!()
      
    elements = Map.get(data, "elements", [])

    nodes = 
      elements
      |> Enum.filter(fn e -> e["type"] == "node" end)
      |> Enum.map(fn n ->
        %OsmNode{
          id: n["id"],
          lat: n["lat"] * 1.0,
          lon: n["lon"] * 1.0,
          tags: normalize_tags(n["tags"])
        }
      end)

    ways = 
      elements
      |> Enum.filter(fn e -> e["type"] == "way" end)
      |> Enum.map(fn w ->
        %OsmWay{
          id: w["id"],
          nodes: w["nodes"],
          tags: normalize_tags(w["tags"])
        }
      end)

    {nodes, ways}
  end

  defp normalize_tags(nil), do: %{}
  defp normalize_tags(tags) when is_map(tags) do
    tags
    |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
    |> Map.new()
  end
end
