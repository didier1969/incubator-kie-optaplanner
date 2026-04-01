# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Solver.Diagnostics do
  @moduledoc "Computes vertical-facing diagnostics from a solved HexaFactory problem."

  @spec score_breakdown(HexaFactory.Generator.Dataset.t(), HexaCore.Domain.Problem.t()) :: map()
  def score_breakdown(dataset, solved_problem) do
    overdue_minutes =
      solved_problem.jobs
      |> Enum.reduce(0, fn job, acc ->
        completion_time = (job.start_time || 0) + job.duration
        due_time = job.due_time || completion_time
        acc + max(completion_time - due_time, 0)
      end)

    late_jobs =
      Enum.count(solved_problem.jobs, fn job ->
        completion_time = (job.start_time || 0) + job.duration
        due_time = job.due_time || completion_time
        completion_time > due_time
      end)

    machine_cost_cents =
      dataset.machines
      |> Enum.reduce(0, fn machine, acc -> acc + machine.hourly_cost_cents end)

    %{
      overdue_minutes: overdue_minutes,
      late_jobs: late_jobs,
      machine_cost_cents: machine_cost_cents
    }
  end
end
