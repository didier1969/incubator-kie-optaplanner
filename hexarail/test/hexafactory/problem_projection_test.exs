# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.ProblemProjectionTest do
  use ExUnit.Case, async: true

  alias HexaCore.Domain.Problem
  alias HexaFactory.Adapter.ProblemProjection
  alias HexaFactory.Generator.Dataset

  test "adapter projects machines, tools, buffers, and transport flows into a generic core problem" do
    dataset = Dataset.build(seed: 7, profile: :smoke)

    problem = ProblemProjection.build(dataset)

    assert %Problem{} = problem
    assert Enum.any?(problem.resources, &String.starts_with?(&1.name, "machine:"))
    assert Enum.any?(problem.resources, &String.starts_with?(&1.name, "tool:"))
    assert Enum.any?(problem.resources, &String.starts_with?(&1.name, "buffer:"))
    assert Enum.any?(problem.resources, &String.starts_with?(&1.name, "transport:"))
    assert Enum.any?(problem.jobs, &(&1.group_id != nil))
    assert Enum.any?(problem.jobs, &(not is_nil(&1.start_time)))

    assert Enum.any?(problem.jobs, fn job ->
             Enum.any?(job.required_resources, fn id ->
               Enum.any?(problem.resources, fn resource ->
                 resource.id == id and String.starts_with?(resource.name, "transport:")
               end)
             end)
           end)

    assert problem.edges != []
    assert problem.score_components != []
  end
end
