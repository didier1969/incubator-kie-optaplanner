# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Native do
  @moduledoc false

  use Rustler,
    otp_app: :hexarail,
    crate: "hexacore_engine",
    path: "native/hexacore_engine",
    target_dir: Path.expand("native/target", File.cwd!())

  @spec add(integer(), integer()) :: integer()
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  @spec evaluate_problem_core(HexaCore.Domain.Problem.t()) :: integer()
  def evaluate_problem_core(_problem), do: :erlang.nif_error(:nif_not_loaded)

  @spec optimize_problem_core(HexaCore.Domain.Problem.t(), String.t(), integer()) ::
          HexaCore.Domain.Problem.t()
  def optimize_problem_core(_problem, _strategy, _iterations), do: :erlang.nif_error(:nif_not_loaded)

  @spec extract_features_core(reference(), HexaCore.Domain.Problem.t(), float()) :: map()
  def extract_features_core(_resource, _problem, _current_time), do: :erlang.nif_error(:nif_not_loaded)

  @spec init_feature_encoder() :: reference()
  def init_feature_encoder(), do: :erlang.nif_error(:nif_not_loaded)

  @spec freeze_feature_encoder(reference()) :: :ok
  def freeze_feature_encoder(_resource), do: :erlang.nif_error(:nif_not_loaded)

  @spec export_feature_vocabularies(reference()) :: String.t()
  def export_feature_vocabularies(_resource), do: :erlang.nif_error(:nif_not_loaded)

  @spec import_feature_vocabularies(String.t()) :: reference()
  def import_feature_vocabularies(_json), do: :erlang.nif_error(:nif_not_loaded)
end
