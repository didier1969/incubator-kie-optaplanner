defmodule HexaPlanner.RollingStock.Vehicle do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "vehicles" do
    field :uic_number, :string
    field :model, :string
    field :mass_tonnes, :float
    field :length_meters, :float
    field :max_speed_kmh, :float
    field :acceleration_ms2, :float

    timestamps()
  end

  def changeset(vehicle, attrs) do
    vehicle
    |> cast(attrs, [:id, :uic_number, :model, :mass_tonnes, :length_meters, :max_speed_kmh, :acceleration_ms2])
    |> validate_required([:id, :uic_number, :model, :mass_tonnes, :length_meters, :max_speed_kmh, :acceleration_ms2])
    |> unique_constraint(:uic_number)
  end
end
