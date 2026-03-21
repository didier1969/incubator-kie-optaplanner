# HexaPlanner Phase 10 Implementation Plan: Open Data Downloader & Parser

> **For Claude/Gemini:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the Elixir mechanism to programmatically download, stream, and parse the massive GeoJSON datasets from the Swiss Open Data portal. This ensures our Digital Twin is built on real, up-to-date physical infrastructure data (tracks, segments) rather than hardcoded mocks.

**Architecture:** Elixir (Control Plane) / `req` HTTP client / `jason` JSON parser.

**Tech Stack:** Elixir, `req`, `jason`.

---

### Task 1: Implement the HTTP Downloader Module

**Files:**
- Create: `hexaplanner/lib/hexaplanner/data/downloader.ex`
- Create: `hexaplanner/test/data/downloader_test.exs`

**Step 1: Write the failing test**
Create `hexaplanner/test/data/downloader_test.exs`:
```elixir
defmodule HexaPlanner.Data.DownloaderTest do
  use ExUnit.Case

  test "downloads SBB GeoJSON with a limit parameter" do
    url = "https://data.sbb.ch/api/explore/v2.1/catalog/datasets/linie-mit-polygon/exports/geojson"
    
    # We fetch just 1 record to avoid massive downloads in tests
    assert {:ok, geojson} = HexaPlanner.Data.Downloader.fetch_geojson(url, limit: 1)
    
    assert geojson["type"] == "FeatureCollection"
    assert length(geojson["features"]) == 1
  end
end
```

**Step 2: Run test to verify it fails**
Run: `nix develop -c bash -c "cd hexaplanner && mix test test/data/downloader_test.exs"`
Expected: FAIL (Undefined module)

**Step 3: Write minimal implementation**
Implement `Downloader.ex` using `Req`.
```elixir
defmodule HexaPlanner.Data.Downloader do
  @moduledoc """
  Handles fetching large datasets from Open Data portals.
  """

  @doc """
  Fetches GeoJSON from a given URL.
  Pass `limit: N` in options to restrict the number of features (useful for testing).
  """
  def fetch_geojson(url, opts \\ []) do
    req_url = 
      case Keyword.get(opts, :limit) do
        nil -> url
        limit -> "#{url}?limit=#{limit}"
      end

    case Req.get(req_url) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}
      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP Request failed with status #{status}"}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Step 4: Run test to verify it passes**
Run: `nix develop -c bash -c "cd hexaplanner && mix test test/data/downloader_test.exs"`
Expected: PASS

**Step 5: Commit**
```bash
git add hexaplanner/
git commit -m "feat(data): implement HTTP downloader for SBB Open Data GeoJSON"
```

---

### Task 2: Create the Track Segment Parser

**Files:**
- Create: `hexaplanner/lib/hexaplanner/data/parser.ex`
- Create: `hexaplanner/test/data/parser_test.exs`

**Step 1: Write the failing test**
Create `hexaplanner/test/data/parser_test.exs` to extract physical tracks from the GeoJSON.
```elixir
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
```

**Step 2: Run test to verify it fails**
Run: `nix develop -c bash -c "cd hexaplanner && mix test test/data/parser_test.exs"`
Expected: FAIL

**Step 3: Write minimal implementation**
We extract the *first and last* coordinate of a `LineString` to define the segment bounds.
```elixir
defmodule HexaPlanner.Data.Parser do
  @moduledoc """
  Parses raw Open Data JSON into Elixir structs.
  """

  defmodule TrackSegment do
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
```

**Step 4: Run test to verify it passes**
Run: `nix develop -c bash -c "cd hexaplanner && mix test test/data/parser_test.exs"`
Expected: PASS

**Step 5: Commit**
```bash
git add hexaplanner/
git commit -m "feat(data): implement GeoJSON parser to extract physical track segments"
```