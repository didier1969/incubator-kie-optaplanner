defmodule HexaPlanner.RollingStock.CompositionVehicle do
  use Ecto.Schema
  import Ecto.Changeset

  schema "composition_vehicles" do
    belongs_to :composition, HexaPlanner.RollingStock.Composition
    belongs_to :vehicle, HexaPlanner.RollingStock.Vehicle, type: :string
    field :position, :integer

    timestamps()
  end

  def changeset(composition_vehicle, attrs) do
    composition_vehicle
    |> cast(attrs, [:composition_id, :vehicle_id, :position])
    |> validate_required([:composition_id, :vehicle_id, :position])
    |> unique_constraint([:composition_id, :position])
  end
end
