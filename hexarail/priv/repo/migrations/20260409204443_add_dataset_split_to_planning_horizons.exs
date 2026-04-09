# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRail.Repo.Migrations.AddDatasetSplitToPlanningHorizons do
  use Ecto.Migration

  def change do
    alter table(:hexafactory_planning_horizons) do
      add :dataset_split, :string, default: "train"
    end
    
    create index(:hexafactory_planning_horizons, [:dataset_split])
  end
end
