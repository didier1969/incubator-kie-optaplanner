# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.VolumetrySmokeTest do
  use ExUnit.Case, async: true

  alias HexaFactory.Generator.Dataset
  alias HexaFactory.Solver.Facade

  test "volumetry smoke profile exercises the same production path with a denser reduced topology" do
    dataset = Dataset.build(seed: 1001, profile: :volumetry_smoke)

    result = Facade.solve(dataset, iterations: 200)

    assert dataset.metadata.target_topology.plant_count == 4
    assert dataset.metadata.target_topology.machines_per_plant == 5
    assert length(dataset.machines) == 20
    assert result.machine_schedules != []
    assert result.score_breakdown.transfer_minutes >= 0
  end
end
