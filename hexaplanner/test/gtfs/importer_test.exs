defmodule HexaPlanner.GTFS.ImporterTest do
  use HexaPlanner.DataCase

  alias HexaPlanner.GTFS.Importer
  alias HexaPlanner.GTFS.Stop
  alias HexaPlanner.Repo

  test "imports stops from CSV file correctly" do
    file_path = "priv/data/stops.txt"
    Importer.import_stops(file_path)

    stops = Repo.all(Stop)
    assert length(stops) == 4

    bern = Repo.get_by(Stop, original_stop_id: "8507000")
    assert bern.stop_name == "Bern"
    assert bern.location.coordinates == {7.4391, 46.9488}
  end
end
