defmodule HexaRailTest do
  use ExUnit.Case
  doctest HexaRail

  test "control plane application starts" do
    assert {:ok, _pid} = Application.ensure_all_started(:hexarail)
  end
end
