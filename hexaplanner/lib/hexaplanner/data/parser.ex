defmodule HexaPlanner.Data.Parser do
  @moduledoc """
  Parses raw Open Data JSON into Elixir structs.
  """

  defmodule TrackSegment do
    @moduledoc """
    Represents a physical connection between two geospatial points.
    """
    @enforce_keys [:line_id, :point_a, :point_b]
    defstruct [:line_id, :point_a, :point_b]
  end

  def extract_segments(%{"features" => features}) do
    features
    |> Enum.filter(fn f -> get_in(f, ["geometry", "type"]) == "LineString" end)
    |> Enum.map(&parse_feature/1)
  end

  defp parse_feature(feature) do
    line_id = get_in(feature, ["properties", "linie"]) || "UNKNOWN"
    coords = get_in(feature, ["geometry", "coordinates"])

    # Take start and end of the line string to form the logical segment
    start_coord = List.first(coords)
    end_coord = List.last(coords)

    %TrackSegment{
      line_id: to_string(line_id),
      point_a: {Enum.at(start_coord, 0), Enum.at(start_coord, 1)},
      point_b: {Enum.at(end_coord, 0), Enum.at(end_coord, 1)}
    }
  end
end
