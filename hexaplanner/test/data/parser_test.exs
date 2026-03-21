defmodule HexaPlanner.Data.ParserTest do
  use ExUnit.Case

  test "extracts track segments from GeoJSON" do
    geojson = %{
      "type" => "FeatureCollection",
      "features" => [
        %{
          "type" => "Feature",
          "properties" => %{"linie" => "100", "km" => "10.5"},
          "geometry" => %{
            "type" => "LineString",
            "coordinates" => [[7.4, 46.9], [7.5, 47.0]]
          }
        }
      ]
    }

    segments = HexaPlanner.Data.Parser.extract_segments(geojson)
    assert length(segments) == 1
    
    segment = hd(segments)
    assert segment.line_id == "100"
    assert segment.point_a == {7.4, 46.9}
    assert segment.point_b == {7.5, 47.0}
  end
end
