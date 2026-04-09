# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Ingestion.PersistedDataset do
  @moduledoc "Persists and reloads solver-ready HexaFactory dataset snapshots."

  alias HexaFactory.Domain.PlanningHorizon
  alias HexaFactory.Generator.Dataset
  alias HexaFactory.RepoBridge

  @spec persist!(Dataset.t(), String.t()) :: map()
  def persist!(%Dataset{} = dataset, split \\ "train") do
    repo = RepoBridge.repo()

    horizon =
      case repo.get_by(PlanningHorizon, signature: dataset.signature) do
        %PlanningHorizon{} = horizon ->
          horizon

        nil ->
          payload =
            dataset
            |> Map.from_struct()
            |> :erlang.term_to_binary()

          repo.insert!(%PlanningHorizon{
            code: "dataset-" <> String.slice(dataset.signature, 0, 11),
            seed: dataset.metadata.seed,
            profile: Atom.to_string(dataset.metadata.profile),
            signature: dataset.signature,
            payload: payload,
            dataset_split: split
          })
      end

    %{
      dataset_ref: horizon.id,
      metadata: dataset.metadata,
      signature: horizon.signature
    }
  end

  @spec persist_expert_trajectory!(integer(), HexaCore.Domain.Problem.t(), map(), map(), map()) :: :ok
  def persist_expert_trajectory!(horizon_id, %HexaCore.Domain.Problem{} = solved_problem, metrics, tensor_x, tensor_y) when is_integer(horizon_id) and is_map(metrics) do
    repo = RepoBridge.repo()
    horizon = repo.get!(PlanningHorizon, horizon_id)
    
    payload =
      solved_problem
      |> Map.from_struct()
      |> :erlang.term_to_binary()

    horizon
    |> Ecto.Changeset.change(%{
      expert_trajectory_payload: payload,
      expert_score_metrics: metrics,
      tensor_x_json: tensor_x,
      tensor_y_json: tensor_y
    })
    |> repo.update!()

    :ok
  end

  @spec load!(integer()) :: Dataset.t()
  def load!(horizon_id) when is_integer(horizon_id) do
    repo = RepoBridge.repo()
    horizon = repo.get!(PlanningHorizon, horizon_id)

    horizon.payload
    |> :erlang.binary_to_term()
    |> then(&struct!(Dataset, &1))
  end
end
