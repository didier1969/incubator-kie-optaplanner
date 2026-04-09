# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.PlanningHorizon do
  @moduledoc "Persisted synthetic planning horizon snapshot for HexaFactory."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_planning_horizons" do
    field(:code, :string)
    field(:seed, :integer)
    field(:profile, :string)
    field(:signature, :string)
    field(:payload, :binary)
    field(:dataset_split, :string)
    field(:expert_trajectory_payload, :binary)
    field(:expert_score_metrics, :map)
    field(:tensor_x_json, :map)
    field(:tensor_y_json, :map)

    timestamps()
  end
end
