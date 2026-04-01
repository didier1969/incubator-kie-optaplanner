# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.NifBoundaryTest do
  use ExUnit.Case, async: true

  alias HexaCore.Nif
  alias HexaRail.{Native, RailwayNif}

  test "generic core nif exposes only agnostic entrypoints while railway facade owns railway operations" do
    assert Code.ensure_loaded?(Nif)
    assert Code.ensure_loaded?(Native)
    assert Code.ensure_loaded?(RailwayNif)

    assert function_exported?(Nif, :add, 2)
    assert function_exported?(Nif, :evaluate_problem_core, 1)
    assert function_exported?(Nif, :optimize_problem_core, 2)

    refute function_exported?(Nif, :init_network, 0)
    refute function_exported?(Nif, :load_stops, 2)
    refute function_exported?(Nif, :load_osm, 3)
    refute function_exported?(Nif, :get_train_position, 3)

    assert function_exported?(RailwayNif, :init_network, 0)
    assert function_exported?(RailwayNif, :load_stops, 2)
    assert function_exported?(RailwayNif, :load_osm, 3)
    assert function_exported?(RailwayNif, :get_train_position, 3)
    refute function_exported?(RailwayNif, :evaluate_problem, 2)
    refute function_exported?(RailwayNif, :optimize_problem, 3)

    assert function_exported?(Native, :add, 2)
    assert function_exported?(Native, :init_network, 0)
    assert function_exported?(Native, :load_stops, 2)
  end
end
