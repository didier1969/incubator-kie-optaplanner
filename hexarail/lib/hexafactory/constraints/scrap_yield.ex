# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Constraints.ScrapYield do
  @moduledoc false

  @spec measure(HexaFactory.Generator.Dataset.t(), HexaCore.Domain.Problem.t()) :: map()
  def measure(dataset, _solved_problem) do
    scrap_units =
      dataset.production_orders
      |> Enum.reduce(0, fn order, acc ->
        order_scrap =
          dataset.bom_items
          |> Enum.filter(&(&1.parent_material_code == order.material_code))
          |> Enum.reduce(0, fn bom_item, bom_acc ->
            bom_acc + trunc(order.quantity * Decimal.to_float(bom_item.scrap_rate))
          end)

        acc + order_scrap
      end)

    %{scrap_units: scrap_units}
  end
end
