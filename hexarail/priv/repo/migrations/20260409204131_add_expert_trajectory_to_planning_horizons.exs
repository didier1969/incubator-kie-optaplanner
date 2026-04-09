# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRail.Repo.Migrations.AddExpertTrajectoryToPlanningHorizons do
  use Ecto.Migration

  def change do
    alter table(:hexafactory_planning_horizons) do
      add :expert_trajectory_payload, :binary
      add :expert_score_metrics, :map
    end
  end
end
