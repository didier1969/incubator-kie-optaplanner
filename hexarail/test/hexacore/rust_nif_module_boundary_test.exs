# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.RustNifModuleBoundaryTest do
  use ExUnit.Case, async: true

  @lib_file Path.expand("../../native/hexacore_engine/src/lib.rs", __DIR__)
  @railway_nif_file Path.expand("../../native/hexacore_engine/src/railway_nif.rs", __DIR__)
  @railway_topology_file Path.expand("../../native/hexacore_engine/src/railway_topology.rs", __DIR__)

  test "generic rust lib keeps only core entrypoints while railway nifs live in a dedicated module" do
    lib_source = File.read!(@lib_file)

    assert lib_source =~ "pub mod railway_nif;"
    assert lib_source =~ "pub mod railway_topology;"
    refute lib_source =~ "fn load_stops("
    refute lib_source =~ "fn load_tracks("
    refute lib_source =~ "fn get_active_positions("
    refute lib_source =~ "use crate::topology::"
    refute lib_source =~ "pub struct NetworkResource"

    assert File.exists?(@railway_nif_file)
    assert File.exists?(@railway_topology_file)

    railway_nif_source = File.read!(@railway_nif_file)

    assert railway_nif_source =~ "pub struct NetworkResource"
    assert railway_nif_source =~ "use crate::railway_topology"
    assert railway_nif_source =~ "fn load_stops("
    assert railway_nif_source =~ "fn get_active_positions("
    assert railway_nif_source =~ "fn resolve_conflict_greedy("

    railway_topology_source = File.read!(@railway_topology_file)

    assert railway_topology_source =~ "pub struct NetworkManager"
    refute railway_topology_source =~ "mod tests"
  end
end
