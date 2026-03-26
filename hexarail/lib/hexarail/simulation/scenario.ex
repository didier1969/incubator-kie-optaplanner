defmodule HexaRail.Simulation.Scenario do
  @moduledoc """
  Represents a pre-programmed crisis scenario with a timeline of perturbations.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "scenarios" do
    field :name, :string
    field :description, :string
    field :data, :map # Stores the list of perturbations

    timestamps()
  end

  def changeset(scenario, attrs) do
    scenario
    |> cast(attrs, [:name, :description, :data])
    |> validate_required([:name, :data])
  end
end
