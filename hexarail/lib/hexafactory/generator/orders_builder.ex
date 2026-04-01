# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Generator.OrdersBuilder do
  @moduledoc "Builds deterministic production orders for the planning horizon."

  alias HexaFactory.Generator.Seed

  @spec build(map(), map(), map(), Seed.state()) :: {map(), Seed.state()}
  def build(config, topology, _materials_data, state) do
    plants = Enum.take(topology.plants, config.order_count)

    {production_orders, state} =
      Enum.map_reduce(Enum.with_index(plants, 1), state, fn {plant, index}, acc_state ->
        {quantity, next_state} = Seed.integer(acc_state, 500, 2_000)

        order = %{
          order_code: "#{plant.code}-PO-#{index}",
          quantity: quantity,
          priority: 1,
          plant_code: plant.code,
          material_code: "#{plant.code}-T1-#{index}"
        }

        {order, next_state}
      end)

    {%{production_orders: production_orders}, state}
  end
end
