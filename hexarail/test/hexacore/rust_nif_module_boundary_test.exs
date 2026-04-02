# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.RustNifModuleBoundaryTest do
  use ExUnit.Case, async: true

  @lib_file Path.expand("../../native/hexacore_engine/src/lib.rs", __DIR__)
  @railway_nif_file Path.expand("../../native/hexacore_engine/src/railway_nif.rs", __DIR__)

  test "generic rust lib keeps only core entrypoints while railway nifs live in a dedicated module" do
    lib_source = File.read!(@lib_file)

    assert lib_source =~ "pub mod railway_nif;"
    refute lib_source =~ "fn load_stops("
    refute lib_source =~ "fn load_tracks("
    refute lib_source =~ "fn get_active_positions("

    assert File.exists?(@railway_nif_file)

    railway_nif_source = File.read!(@railway_nif_file)

    assert railway_nif_source =~ "fn load_stops("
    assert railway_nif_source =~ "fn get_active_positions("
    assert railway_nif_source =~ "fn resolve_conflict_greedy("
  end
end
