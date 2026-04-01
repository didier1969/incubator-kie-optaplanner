# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Constraints.Maintenance do
  @moduledoc false

  @spec measure(HexaFactory.Generator.Dataset.t(), HexaCore.Domain.Problem.t()) :: map()
  def measure(_dataset, solved_problem) do
    maintenance_jobs = Enum.filter(solved_problem.jobs, &maintenance_job?/1)
    scheduled_jobs = Enum.reject(solved_problem.jobs, &maintenance_job?/1)

    maintenance_conflicts =
      maintenance_jobs
      |> Enum.reduce(0, fn maintenance_job, acc ->
        overlaps =
          Enum.count(scheduled_jobs, fn job ->
            overlapping?(maintenance_job, job) and shared_resources?(maintenance_job, job)
          end)

        acc + overlaps
      end)

    %{maintenance_conflicts: maintenance_conflicts}
  end

  defp maintenance_job?(job) do
    not is_nil(job.start_time) and
      length(job.required_resources) == 1 and
      job.release_time == job.start_time and
      job.due_time == job.start_time + job.duration
  end

  defp overlapping?(left, right) do
    left_start = left.start_time || 0
    left_end = left_start + left.duration
    right_start = right.start_time || 0
    right_end = right_start + right.duration

    left_start < right_end and right_start < left_end
  end

  defp shared_resources?(left, right) do
    not MapSet.disjoint?(MapSet.new(left.required_resources), MapSet.new(right.required_resources))
  end
end
