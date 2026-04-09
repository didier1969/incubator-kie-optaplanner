# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRail.Repo.Migrations.AddTensorJsonToPlanningHorizons do
  use Ecto.Migration

  def change do
    alter table(:hexafactory_planning_horizons) do
      add :tensor_x_json, :map
      add :tensor_y_json, :map
    end
  end
end
