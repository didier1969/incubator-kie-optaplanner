defmodule HexaPlanner.GTFS.StopTest do
  use HexaPlanner.DataCase

  alias HexaPlanner.GTFS.Stop
  alias HexaPlanner.Repo

  test "insert and retrieve a GTFS stop with geospatial point" do
    # Coordinates for a generic train station
    point = %Geo.Point{coordinates: {7.4391, 46.9488}, srid: 4326}

    changeset =
      Stop.changeset(%Stop{}, %{
        original_stop_id: "STATION_001",
        stop_name: "Central Station",
        location: point
      })

    assert {:ok, stop} = Repo.insert(changeset)
    assert stop.stop_name == "Central Station"
    assert stop.original_stop_id == "STATION_001"
  end
end
