# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.CoreSolverTest do
  use ExUnit.Case

  alias HexaCore.Domain.{Job, Problem}
  alias HexaCore.Nif

  test "scores and optimizes a generic problem without railway resource state" do
    problem = %Problem{
      id: "logistics_1",
      resources: [],
      jobs: [
        %Job{id: 1, duration: 15, required_resources: [], start_time: nil},
        %Job{id: 2, duration: 20, required_resources: [], start_time: 30}
      ]
    }

    score = Nif.evaluate_problem_core(problem)
    assert score.hard == 0
    assert score.medium == -1

    optimized_problem = Nif.optimize_problem_core(problem, "metaheuristic", 10)

    score_after = Nif.evaluate_problem_core(optimized_problem)
    assert score_after.hard == 0
    assert score_after.medium == 0
    assert hd(optimized_problem.jobs).start_time != nil
  end

  test "returns not_implemented for nco strategy" do
    problem = %Problem{
      id: "logistics_1",
      resources: [],
      jobs: [],
      edges: [],
      score_components: []
    }

    assert_raise ErlangError, ~r/not_implemented/, fn ->
      Nif.optimize_problem_core(problem, "nco", 10)
    end
  end
end
