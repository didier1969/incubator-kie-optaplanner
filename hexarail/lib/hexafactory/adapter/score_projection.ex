# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Adapter.ScoreProjection do
  @moduledoc "Projects vertical score metadata into generic HexaCore score components."

  alias HexaCore.Domain.ScoreComponent

  @spec build(HexaFactory.Generator.Dataset.t()) :: list(ScoreComponent.t())
  def build(dataset) do
    [
      %ScoreComponent{name: "plants", value: length(dataset.plants)},
      %ScoreComponent{name: "machines", value: length(dataset.machines)},
      %ScoreComponent{name: "orders", value: length(dataset.production_orders)}
    ]
  end
end
