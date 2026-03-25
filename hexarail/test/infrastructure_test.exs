defmodule HexaRail.InfrastructureTest do
  use ExUnit.Case

  test "Horde is running in the supervision tree" do
    assert Process.whereis(HexaRail.HordeRegistry) != nil
    assert Process.whereis(HexaRail.HordeSupervisor) != nil
  end

  test "Oban is running in the supervision tree" do
    assert Process.whereis(Oban.Registry) != nil
  end
end
