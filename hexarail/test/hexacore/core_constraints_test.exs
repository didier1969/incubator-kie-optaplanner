# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.CoreConstraintsTest do
  use ExUnit.Case, async: true

  alias HexaCore.Domain.{Edge, Job, Problem, Resource, Window}
  alias HexaCore.Nif

  test "core evaluation penalizes precedence, due date, and availability violations" do
    problem = %Problem{
      id: "core-generic",
      resources: [
        %Resource{
          id: 1,
          name: "machine-1",
          capacity: 1,
          availability_windows: [%Window{start_at: 0, end_at: 60}]
        }
      ],
      jobs: [
        %Job{
          id: 1,
          duration: 50,
          required_resources: [1],
          release_time: 0,
          due_time: 40,
          start_time: 30
        },
        %Job{
          id: 2,
          duration: 10,
          required_resources: [1],
          release_time: 0,
          due_time: 20,
          start_time: 0
        }
      ],
      edges: [
        %Edge{from_job_id: 1, to_job_id: 2, lag: 0, edge_type: "finish_to_start"}
      ]
    }

    score = Nif.evaluate_problem_core(problem)
    assert score.hard < 0
    assert score.soft < 0
    assert score.medium == 0
  end
end
