defmodule HexaPlanner.Data.DownloaderTest do
  use ExUnit.Case

  alias HexaPlanner.Data.Downloader

  test "downloads SBB GeoJSON with a limit parameter" do
    url = "https://data.sbb.ch/api/explore/v2.1/catalog/datasets/linie-mit-polygon/exports/geojson"

    # We fetch just 1 record to avoid massive downloads in tests
    assert {:ok, geojson} = Downloader.fetch_geojson(url, limit: 1)

    assert geojson["type"] == "FeatureCollection"
    assert length(geojson["features"]) == 1
  end
end
