defmodule HexaRail.GTFS.ImporterTest do
  use HexaRail.DataCase

  alias HexaRail.GTFS.Importer
  alias HexaRail.GTFS.Stop
  alias HexaRail.Repo

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
