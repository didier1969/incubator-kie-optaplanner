# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Nif do
  @moduledoc """
  Agnostic public facade over the Rust core optimization bridge.
  """

  alias HexaCore.Native

  defdelegate add(a, b), to: Native
  defdelegate evaluate_problem_core(problem), to: Native
  defdelegate optimize_problem_core(problem, iterations), to: Native
end
