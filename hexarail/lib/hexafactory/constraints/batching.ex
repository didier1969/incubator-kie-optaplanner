# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Constraints.Batching do
  @moduledoc false

  @spec measure(HexaFactory.Generator.Dataset.t(), HexaCore.Domain.Problem.t()) :: map()
  def measure(_dataset, solved_problem) do
    batched_jobs =
      Enum.count(solved_problem.jobs, fn job ->
        is_binary(job.group_id) and String.starts_with?(job.group_id, "batch:")
      end)

    %{batched_jobs: batched_jobs}
  end
end
