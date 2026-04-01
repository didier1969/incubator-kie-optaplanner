# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Constraints.BufferCapacity do
  @moduledoc false

  @spec measure(HexaFactory.Generator.Dataset.t(), HexaCore.Domain.Problem.t()) :: map()
  def measure(_dataset, solved_problem) do
    resources_by_id = Map.new(solved_problem.resources, &{&1.id, &1})

    loads_by_buffer =
      solved_problem.jobs
      |> Enum.filter(& &1.start_time)
      |> Enum.flat_map(fn job ->
        job.required_resources
        |> Enum.map(&Map.get(resources_by_id, &1))
        |> Enum.filter(& &1)
        |> Enum.filter(&String.starts_with?(&1.name, "buffer:"))
        |> Enum.map(& &1.id)
      end)
      |> Enum.frequencies()

    buffer_violations =
      solved_problem.resources
      |> Enum.filter(&String.starts_with?(&1.name, "buffer:"))
      |> Enum.reduce(0, fn resource, acc ->
        load = Map.get(loads_by_buffer, resource.id, 0)
        acc + max(load - resource.capacity, 0)
      end)

    %{buffer_violations: buffer_violations}
  end
end
