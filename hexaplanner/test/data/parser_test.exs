defmodule HexaPlanner.Data.ParserTest do
  use ExUnit.Case

  alias HexaPlanner.Data.Parser

  test "extracts track segments from GeoJSON" do
    geojson = %{
      "type" => "FeatureCollection",
      "features" => [
        %{
          "type" => "Feature",
          "properties" => %{"linie" => "100", "km" => "10.5"},
          "geometry" => %{
            "type" => "LineString",
            "coordinates" => [[7.4, 46.9], [7.45, 46.95], [7.5, 47.0]]
          }
        }
      ]
    }

    segments = Parser.extract_segments(geojson)
    assert length(segments) == 1

    segment = hd(segments)
    assert segment.line_id == "100"
    assert segment.coordinates == [{7.4, 46.9}, {7.45, 46.95}, {7.5, 47.0}]
    assert segment.properties == %{"linie" => "100", "km" => "10.5"}
  end
end
