# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Constraints.LaborSkill do
  @moduledoc false

  @spec measure(HexaFactory.Generator.Dataset.t(), HexaCore.Domain.Problem.t()) :: map()
  def measure(_dataset, solved_problem) do
    resources_by_id = Map.new(solved_problem.resources, &{&1.id, &1})

    labor_coverage_ratio =
      solved_problem.jobs
      |> Enum.filter(& &1.start_time)
      |> Enum.reduce({0, 0}, fn job, {covered_jobs, scheduled_jobs} ->
        labor_assigned? =
          Enum.any?(job.required_resources, fn resource_id ->
            case Map.get(resources_by_id, resource_id) do
              %{name: <<"labor_pool:", _::binary>>} -> true
              _ -> false
            end
          end)

        {covered_jobs + if(labor_assigned?, do: 1, else: 0), scheduled_jobs + 1}
      end)
      |> case do
        {_covered_jobs, 0} -> 100
        {covered_jobs, scheduled_jobs} -> div(covered_jobs * 100, scheduled_jobs)
      end

    %{labor_coverage_ratio: labor_coverage_ratio}
  end
end
