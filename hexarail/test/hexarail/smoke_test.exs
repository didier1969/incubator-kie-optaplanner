# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRail.SmokeTest do
  use ExUnit.Case, async: true

  alias HexaRail.Smoke

  test "runs a deterministic railway smoke path through perturbation and resolution" do
    summary = Smoke.run(strategy: :greedy, perturbation_start_time: 120, query_time: 150)

    assert summary.tracks_loaded == 1
    assert summary.active_positions_before == 2
    assert summary.active_positions_after == 0
    assert summary.resolution_status == "success"
    assert summary.trains_impacted >= 1
  end
end
