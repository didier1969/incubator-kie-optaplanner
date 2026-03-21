defmodule HexaPlannerTest do
  use ExUnit.Case
  doctest HexaPlanner

  test "control plane application starts" do
    assert {:ok, _pid} = Application.ensure_all_started(:hexaplanner)
  end
end
