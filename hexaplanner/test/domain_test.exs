defmodule HexaPlanner.DomainTest do
  use ExUnit.Case
  alias HexaCore.Domain.{Job, Problem, Resource}

  test "a problem can be modeled immutably" do
    r1 = %Resource{id: 1, name: "Machine A", capacity: 1}
    j1 = %Job{id: 100, duration: 60, required_resources: [1]}

    problem = %Problem{id: "sim_1", resources: [r1], jobs: [j1]}
    assert length(problem.jobs) == 1
  end
end
