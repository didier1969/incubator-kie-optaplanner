# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Native do
  @moduledoc false

  use Rustler, otp_app: :hexarail, crate: "hexacore_engine"

  @spec add(integer(), integer()) :: integer()
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  @spec evaluate_problem_core(HexaCore.Domain.Problem.t()) :: integer()
  def evaluate_problem_core(_problem), do: :erlang.nif_error(:nif_not_loaded)

  @spec optimize_problem_core(HexaCore.Domain.Problem.t(), integer()) ::
          HexaCore.Domain.Problem.t()
  def optimize_problem_core(_problem, _iterations), do: :erlang.nif_error(:nif_not_loaded)
end
