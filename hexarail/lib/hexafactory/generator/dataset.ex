# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Generator.Dataset do
  @moduledoc "Deterministic synthetic manufacturing dataset for HexaFactory."

  alias HexaFactory.Generator.{
    CapacityBuilder,
    MaterialsBuilder,
    OrdersBuilder,
    RoutingBuilder,
    Seed,
    SetupBuilder,
    TopologyBuilder
  }

  @enforce_keys [:metadata, :signature]
  defstruct metadata: %{},
            signature: nil,
            company_codes: [],
            plants: [],
            storage_locations: [],
            materials: [],
            work_centers: [],
            machines: [],
            skills: [],
            operators: [],
            labor_pools: [],
            tools: [],
            tool_instances: [],
            transport_lanes: [],
            bom_items: [],
            routings: [],
            routing_operations: [],
            production_orders: [],
            setup_profiles: [],
            setup_transitions: [],
            maintenance_windows: [],
            buffers: [],
            batch_policies: []

  @type t :: %__MODULE__{}

  @spec build(keyword()) :: t()
  def build(opts) do
    seed = Keyword.get(opts, :seed, 42)
    profile = Keyword.get(opts, :profile, :smoke)
    config = profile_config(profile)

    state = Seed.new(seed)

    {topology, state} = TopologyBuilder.build(config, state)
    {materials_data, state} = MaterialsBuilder.build(config, topology, state)
    {routing_data, state} = RoutingBuilder.build(config, topology, materials_data, state)
    {capacity_data, state} = CapacityBuilder.build(config, topology, materials_data, state)
    {setup_data, state} = SetupBuilder.build(config, topology, materials_data, state)
    {orders_data, _state} = OrdersBuilder.build(config, topology, materials_data, state)

    metadata = %{
      seed: seed,
      profile: profile,
      target_topology: %{
        plant_count: config.plant_count,
        machines_per_plant: config.machines_per_plant
      }
    }

    payload = %{
      metadata: metadata,
      company_codes: topology.company_codes,
      plants: topology.plants,
      storage_locations: topology.storage_locations,
      materials: materials_data.materials,
      work_centers: topology.work_centers,
      machines: topology.machines,
      skills: topology.skills,
      operators: topology.operators,
      labor_pools: topology.labor_pools,
      tools: topology.tools,
      tool_instances: topology.tool_instances,
      transport_lanes: routing_data.transport_lanes,
      bom_items: materials_data.bom_items,
      routings: routing_data.routings,
      routing_operations: routing_data.routing_operations,
      production_orders: orders_data.production_orders,
      setup_profiles: setup_data.setup_profiles,
      setup_transitions: setup_data.setup_transitions,
      maintenance_windows: capacity_data.maintenance_windows,
      buffers: capacity_data.buffers,
      batch_policies: setup_data.batch_policies
    }

    signature =
      payload
      |> :erlang.term_to_binary()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    struct!(__MODULE__, Map.put(payload, :signature, signature))
  end

  defp profile_config(:smoke), do: %{plant_count: 2, machines_per_plant: 3, order_count: 2}
  defp profile_config(:interaction), do: %{plant_count: 3, machines_per_plant: 4, order_count: 3}
  defp profile_config(:volumetry_smoke), do: %{plant_count: 4, machines_per_plant: 5, order_count: 4}
  defp profile_config(:target_60_plant), do: %{plant_count: 60, machines_per_plant: 200, order_count: 60}
end
