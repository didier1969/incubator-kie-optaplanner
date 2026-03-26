defmodule HexaRail.Repo.Migrations.CreateScenarios do
  use Ecto.Migration

  def change do
    create table(:scenarios, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :data, :map, null: false

      timestamps()
    end

    create unique_index(:scenarios, [:name])
  end
end
