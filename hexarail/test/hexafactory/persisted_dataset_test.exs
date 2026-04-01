# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.PersistedDatasetTest do
  use HexaRail.DataCase, async: true

  alias HexaFactory.Generator.Dataset
  alias HexaFactory.Ingestion.PersistedDataset

  test "generated dataset can be persisted and reloaded without losing industrial semantics" do
    dataset = Dataset.build(seed: 123, profile: :smoke)

    persisted = PersistedDataset.persist!(dataset)
    reloaded = PersistedDataset.load!(persisted.dataset_ref)

    assert reloaded.metadata == persisted.metadata
    assert length(reloaded.company_codes) == length(dataset.company_codes)
    assert length(reloaded.materials) == length(dataset.materials)
    assert length(reloaded.setup_transitions) == length(dataset.setup_transitions)
    assert length(reloaded.production_orders) == length(dataset.production_orders)
  end
end
