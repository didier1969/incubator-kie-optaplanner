# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Constraints.Transport do
  @moduledoc false

  @spec measure(HexaFactory.Generator.Dataset.t(), HexaCore.Domain.Problem.t()) :: map()
  def measure(_dataset, solved_problem) do
    transfer_minutes =
      solved_problem.jobs
      |> Enum.filter(fn job ->
        is_binary(job.batch_key) and String.starts_with?(job.batch_key, "transfer:")
      end)
      |> Enum.reduce(0, fn job, acc -> acc + job.duration end)

    %{transfer_minutes: transfer_minutes}
  end
end
