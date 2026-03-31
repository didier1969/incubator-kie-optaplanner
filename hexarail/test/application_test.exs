# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRail.ApplicationTest do
  use ExUnit.Case

  test "does not start the simulation engine in test environment" do
    child_ids =
      HexaRail.Supervisor
      |> Supervisor.which_children()
      |> Enum.map(fn {id, _pid, _type, _modules} -> id end)

    refute HexaRail.Simulation.Engine in child_ids
  end
end
