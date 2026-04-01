# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Constraints.MachineCost do
  @moduledoc false

  @spec measure(HexaFactory.Generator.Dataset.t(), HexaCore.Domain.Problem.t()) :: map()
  def measure(dataset, solved_problem) do
    resources_by_id = Map.new(solved_problem.resources, &{&1.id, &1})

    used_machine_codes =
      solved_problem.jobs
      |> Enum.filter(& &1.start_time)
      |> Enum.flat_map(fn job ->
        job.required_resources
        |> Enum.map(&Map.get(resources_by_id, &1))
        |> Enum.filter(& &1)
        |> Enum.filter(&String.starts_with?(&1.name, "machine:"))
        |> Enum.map(&String.replace_prefix(&1.name, "machine:", ""))
      end)
      |> MapSet.new()

    machine_cost_cents =
      dataset.machines
      |> Enum.filter(&MapSet.member?(used_machine_codes, &1.code))
      |> Enum.reduce(0, fn machine, acc -> acc + machine.hourly_cost_cents end)

    %{machine_cost_cents: machine_cost_cents}
  end
end
