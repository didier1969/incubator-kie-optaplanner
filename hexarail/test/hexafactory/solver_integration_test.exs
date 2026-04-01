# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.SolverIntegrationTest do
  use ExUnit.Case, async: true

  alias HexaFactory.Generator.Dataset
  alias HexaFactory.Solver.Facade

  test "hexafactory solves a reduced industrial horizon through the generic hexacore boundary" do
    dataset = Dataset.build(seed: 99, profile: :smoke)

    result = Facade.solve(dataset, iterations: 250)

    assert result.score_breakdown.late_jobs >= 0
    assert result.machine_schedules != []
    assert result.transfer_plan != []
    assert result.buffer_diagnostics != []
  end
end
