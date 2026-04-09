# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Nif do
  @moduledoc """
  Agnostic public facade over the Rust core optimization bridge.
  """

  alias HexaCore.Native

  defdelegate add(a, b), to: Native
  defdelegate evaluate_problem_core(problem), to: Native
  defdelegate optimize_problem_core(problem, strategy, iterations), to: Native
  defdelegate init_feature_encoder(), to: Native
  defdelegate freeze_feature_encoder(resource), to: Native
  defdelegate export_feature_vocabularies(resource), to: Native
  defdelegate import_feature_vocabularies(json), to: Native
  defdelegate extract_features_core(resource, problem), to: Native
end
