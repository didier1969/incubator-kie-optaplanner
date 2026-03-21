defmodule HexaPlanner.InfrastructureTest do
  use ExUnit.Case

  test "Horde is running in the supervision tree" do
    assert Process.whereis(HexaPlanner.HordeRegistry) != nil
    assert Process.whereis(HexaPlanner.HordeSupervisor) != nil
  end
end
