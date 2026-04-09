# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.RustDomainBoundaryTest do
  use ExUnit.Case, async: true

  @domain_file Path.expand("../../native/hexacore_logic/src/domain.rs", __DIR__)
  @legacy_railway_domain_file Path.expand("../../native/hexacore_logic/src/railway_domain.rs", __DIR__)
  @railway_domain_file Path.expand("../../native/hexarail_engine/src/railway_domain.rs", __DIR__)

  test "generic rust domain stays core-only while railway rust structs live in a dedicated module" do
    domain_source = File.read!(@domain_file)

    refute domain_source =~ ~s([module = "HexaRail.)
    refute File.exists?(@legacy_railway_domain_file)
    assert File.exists?(@railway_domain_file)

    railway_source = File.read!(@railway_domain_file)

    assert railway_source =~ ~s([module = "HexaRail.)
    assert railway_source =~ "pub struct GtfsStop"
    assert railway_source =~ "pub struct ActivePosition"
  end
end
