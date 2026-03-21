defmodule HexaPlanner.SolverIntegrationTest do
  use ExUnit.Case
  alias HexaPlanner.Domain.{Job, Problem}
  alias HexaPlanner.SolverNif

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
    assert SolverNif.evaluate_problem(problem) == -100
  end
end
