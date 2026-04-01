# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRail.Repo.Migrations.CreateHexafactoryPlanningHorizons do
  use Ecto.Migration

  def change do
    create table(:hexafactory_planning_horizons) do
      add(:code, :string, null: false)
      add(:seed, :integer, null: false)
      add(:profile, :string, null: false)
      add(:signature, :string, null: false)
      add(:payload, :binary, null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_planning_horizons, [:code]))
    create(unique_index(:hexafactory_planning_horizons, [:signature]))
  end
end
