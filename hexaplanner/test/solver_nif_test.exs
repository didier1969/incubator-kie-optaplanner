defmodule HexaPlanner.SolverNifTest do
  use ExUnit.Case

  test "rustler bridge can add two numbers via pure rust solver" do
    assert HexaPlanner.SolverNif.add(2, 3) == 5
  end
end
