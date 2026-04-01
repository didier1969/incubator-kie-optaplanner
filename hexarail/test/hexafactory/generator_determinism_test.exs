# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.GeneratorDeterminismTest do
  use ExUnit.Case, async: true

  alias HexaFactory.Generator.Dataset

  test "generator is deterministic for the same seed and profile" do
    left = Dataset.build(seed: 42, profile: :smoke)
    right = Dataset.build(seed: 42, profile: :smoke)

    assert left.signature == right.signature
    assert left.metadata.seed == 42
    assert right.metadata.profile == :smoke
  end
end
