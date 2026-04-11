# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.ProblemContractTest do
  use ExUnit.Case, async: true

  alias HexaCore.Domain.{Edge, Job, Problem, Resource, Window}

  test "generic problem carries precedence edges, availability windows, and due dates" do
    problem = %Problem{
      id: "factory-horizon",
      resources: [
        %Resource{
          id: 1,
          name: "machine-1",
          capacity: 1,
          availability_windows: [%Window{start_at: 0, end_at: 480}]
        }
      ],
      jobs: [
        %Job{
          id: 10,
          duration: 120,
          required_resources: [1],
          release_time: 0,
          due_time: 240,
          group_id: "heat-a"
        },
        %Job{
          id: 11,
          duration: 60,
          required_resources: [1],
          release_time: 150,
          due_time: 360,
          group_id: "heat-a"
        }
      ],
      edges: [
        %Edge{from_job_id: 10, to_job_id: 11, lag: 30, edge_type: "finish_to_start"}
      ]
    }

    assert length(problem.edges) == 1
    assert hd(problem.resources).availability_windows == [%Window{start_at: 0, end_at: 480}]
    assert Enum.map(problem.jobs, & &1.due_time) == [240, 360]
  end
end
