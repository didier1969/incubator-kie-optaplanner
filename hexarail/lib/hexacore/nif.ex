# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Nif do
  @moduledoc """
  Agnostic public facade over the Rust core optimization bridge.
  """

  alias HexaCore.Native

  defdelegate add(a, b), to: Native
  defdelegate evaluate_problem_core(problem), to: Native
  defdelegate optimize_problem_core(problem, strategy, iterations), to: Native
  defdelegate extract_features_core(problem), to: Native
end
