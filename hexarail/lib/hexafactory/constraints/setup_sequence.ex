# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Constraints.SetupSequence do
  @moduledoc false

  @spec measure(HexaFactory.Generator.Dataset.t(), HexaCore.Domain.Problem.t()) :: map()
  def measure(dataset, solved_problem) do
    setup_duration =
      dataset.setup_transitions
      |> List.first()
      |> case do
        %{duration_minutes: duration_minutes} -> duration_minutes
        _ -> 0
      end

    resources_by_id = Map.new(solved_problem.resources, &{&1.id, &1})

    setup_minutes =
      solved_problem.jobs
      |> Enum.filter(& &1.start_time)
      |> Enum.reduce(%{}, fn job, acc ->
        machine_resources =
          job.required_resources
          |> Enum.map(&Map.get(resources_by_id, &1))
          |> Enum.filter(& &1)
          |> Enum.filter(&String.starts_with?(&1.name, "machine:"))

        Enum.reduce(machine_resources, acc, fn resource, machine_acc ->
          group_id = job.group_id || "no-setup"
          Map.update(machine_acc, resource.name, MapSet.new([group_id]), &MapSet.put(&1, group_id))
        end)
      end)
      |> Enum.reduce(0, fn
        {_machine, group_ids}, acc when map_size(group_ids) == 0 -> acc
        {_machine, group_ids}, acc -> acc + MapSet.size(group_ids) * setup_duration
      end)

    %{setup_minutes: setup_minutes}
  end
end
