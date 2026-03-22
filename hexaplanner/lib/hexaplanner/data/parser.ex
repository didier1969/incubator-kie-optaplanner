defmodule HexaPlanner.Data.Parser do
  @moduledoc """
  Parses raw Open Data JSON into Elixir structs.
  """

  defmodule TrackSegment do
    @moduledoc """
    Represents a physical connection between two geospatial points.
    """
    @enforce_keys [:line_id, :coordinates]
    defstruct [:line_id, :coordinates, properties: %{}]
  end

  def extract_segments(%{"features" => features}) do
    features
    |> Enum.filter(fn f -> get_in(f, ["geometry", "type"]) == "LineString" end)
    |> Enum.map(&parse_feature/1)
  end

  defp parse_feature(feature) do
    properties = Map.get(feature, "properties", %{})
    line_id = Map.get(properties, "linie", "UNKNOWN")
    coords = get_in(feature, ["geometry", "coordinates"]) || []

    parsed_coords = Enum.map(coords, fn [lon, lat | _] -> {lon, lat} end)

    %TrackSegment{
      line_id: to_string(line_id),
      coordinates: parsed_coords,
      properties: properties
    }
  end
end
