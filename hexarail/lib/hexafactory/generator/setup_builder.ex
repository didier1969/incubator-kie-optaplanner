# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Generator.SetupBuilder do
  @moduledoc "Builds deterministic setup profiles, transitions, and batch policies."

  @spec build(map(), map(), map(), term()) :: {map(), term()}
  def build(_config, topology, _materials_data, state) do
    setup_profiles =
      Enum.map(topology.plants, fn plant ->
        %{code: "#{plant.code}-THERM-HOT", description: "#{plant.code} hot thermal profile"}
      end)

    setup_transitions =
      Enum.map(setup_profiles, fn profile ->
        %{from_profile_code: profile.code, to_profile_code: profile.code, duration_minutes: 45}
      end)

    batch_policies =
      Enum.map(topology.plants, fn plant ->
        %{
          code: "#{plant.code}-BATCH-THERM",
          operation_kind: "heat_treatment",
          min_batch_size: 100,
          max_batch_size: 400,
          mix_key: "thermal_profile"
        }
      end)

    {%{setup_profiles: setup_profiles, setup_transitions: setup_transitions, batch_policies: batch_policies}, state}
  end
end
