# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.ConstraintInteractionsTest do
  use ExUnit.Case, async: true

  alias HexaFactory.Generator.Dataset
  alias HexaFactory.Solver.Facade

  test "constraint diagnostics expose due date, setup, cost, transfer, buffer, maintenance, and scrap signals" do
    dataset = Dataset.build(seed: 555, profile: :interaction)

    result = Facade.solve(dataset, iterations: 400)
    breakdown = result.score_breakdown

    assert breakdown.overdue_minutes >= 0
    assert breakdown.late_jobs >= 0
    assert breakdown.setup_minutes >= 0
    assert breakdown.machine_cost_cents >= 0
    assert breakdown.transfer_minutes >= 0
    assert breakdown.buffer_violations >= 0
    assert breakdown.maintenance_conflicts >= 0
    assert breakdown.scrap_units >= 0
  end
end
