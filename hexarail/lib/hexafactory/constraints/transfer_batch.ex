# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Constraints.TransferBatch do
  @moduledoc false

  @spec measure(HexaFactory.Generator.Dataset.t(), HexaCore.Domain.Problem.t()) :: map()
  def measure(_dataset, solved_problem) do
    transfer_batches =
      Enum.count(solved_problem.jobs, fn job ->
        is_binary(job.group_id) and String.starts_with?(job.group_id, "transfer:")
      end)

    %{transfer_batches: transfer_batches}
  end
end
