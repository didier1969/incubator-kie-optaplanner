defmodule HexaRail.RollingStock.Composition do
  use Ecto.Schema
  import Ecto.Changeset

  schema "compositions" do
    field :trip_id, :integer
    field :total_mass_tonnes, :float
    field :total_length_meters, :float

    has_many :composition_vehicles, HexaRail.RollingStock.CompositionVehicle
    has_many :vehicles, through: [:composition_vehicles, :vehicle]

    timestamps()
  end

  def changeset(composition, attrs) do
    composition
    |> cast(attrs, [:trip_id, :total_mass_tonnes, :total_length_meters])
    |> validate_required([:trip_id, :total_mass_tonnes, :total_length_meters])
  end
end
