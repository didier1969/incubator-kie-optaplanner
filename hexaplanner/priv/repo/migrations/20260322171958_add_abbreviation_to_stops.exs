defmodule HexaPlanner.Repo.Migrations.AddAbbreviationToStops do
  use Ecto.Migration

  def change do
    alter table(:gtfs_stops) do
      add :abbreviation, :string
    end
  end
end
