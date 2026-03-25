defmodule HexaRail.RollingStock.SchemaTest do
  use HexaRail.DataCase
  alias HexaRail.RollingStock.{Vehicle, Composition, CompositionVehicle}

  test "validates required vehicle fields" do
    changeset = Vehicle.changeset(%Vehicle{}, %{})

    assert %{
             id: ["can't be blank"],
             uic_number: ["can't be blank"],
             model: ["can't be blank"],
             mass_tonnes: ["can't be blank"],
             length_meters: ["can't be blank"],
             max_speed_kmh: ["can't be blank"],
             acceleration_ms2: ["can't be blank"]
           } = errors_on(changeset)
  end

  test "validates required composition fields" do
    changeset = Composition.changeset(%Composition{}, %{})

    assert %{
             trip_id: ["can't be blank"],
             total_mass_tonnes: ["can't be blank"],
             total_length_meters: ["can't be blank"]
           } = errors_on(changeset)
  end

  test "validates required composition_vehicle fields" do
    changeset = CompositionVehicle.changeset(%CompositionVehicle{}, %{})

    assert %{
             composition_id: ["can't be blank"],
             vehicle_id: ["can't be blank"],
             position: ["can't be blank"]
           } = errors_on(changeset)
  end
end
