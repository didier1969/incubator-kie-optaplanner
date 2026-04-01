# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.DomainBoundaryTest do
  use ExUnit.Case, async: true

  alias HexaCore.Domain.{Job, Resource}

  test "generic core domain structs are plain data contracts without Ecto schema baggage" do
    assert Code.ensure_loaded?(Job)
    assert Code.ensure_loaded?(Resource)

    refute function_exported?(Job, :__schema__, 1)
    refute function_exported?(Resource, :__schema__, 1)

    assert %Job{required_resources: []} = %Job{}
    assert %Resource{capacity: 1, availability_windows: []} = %Resource{}
  end
end
