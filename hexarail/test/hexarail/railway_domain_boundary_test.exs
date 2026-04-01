# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRail.RailwayDomainBoundaryTest do
  use ExUnit.Case, async: true

  test "railway-only nif structs live under HexaRail.Domain" do
    assert Code.ensure_loaded?(HexaRail.Domain.Perturbation)
    assert Code.ensure_loaded?(HexaRail.Domain.SystemHealth)
    assert Code.ensure_loaded?(HexaRail.Domain.ActivePosition)
    assert Code.ensure_loaded?(HexaRail.Domain.EOS)
    assert Code.ensure_loaded?(HexaRail.Domain.Conflict)
    assert Code.ensure_loaded?(HexaRail.Domain.ConflictSummary)
    assert Code.ensure_loaded?(HexaRail.Domain.ResolutionMetrics)
    assert Code.ensure_loaded?(HexaRail.Domain.CompactEOS)
  end
end
