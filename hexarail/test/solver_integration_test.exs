# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRail.SolverIntegrationTest do
  use ExUnit.Case
  alias HexaCore.Domain.{Job, Problem}
  alias HexaCore.Nif

  test "rust nif calculates penalty for unassigned jobs" do
    problem = %Problem{
      id: "sim_1",
      resources: [],
      jobs: [
        %Job{id: 1, duration: 10, required_resources: [], start_time: nil},
        %Job{id: 2, duration: 10, required_resources: [], start_time: 50}
      ]
    }

    # Should be -100 because 1 job is unassigned
    assert Nif.evaluate_problem_core(problem) == -100
  end

  test "rust nif optimizes the problem and returns mutated state" do
    problem = %Problem{
      id: "sim_2",
      resources: [],
      jobs: [
        %Job{id: 1, duration: 10, required_resources: [], start_time: nil}
      ]
    }

    assert Nif.evaluate_problem_core(problem) == -100

    optimized_problem = Nif.optimize_problem_core(problem, "metaheuristic", 10)

    assert Nif.evaluate_problem_core(optimized_problem) == 0
    # Ensure the Rust engine actually mutated the struct and sent it back
    assert hd(optimized_problem.jobs).start_time != nil
  end
end
