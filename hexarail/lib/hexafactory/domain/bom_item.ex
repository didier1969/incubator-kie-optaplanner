# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.BomItem do
  @moduledoc "Directed BOM edge between a parent material and one component material."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_bom_items" do
    field(:quantity_per_parent, :decimal)
    field(:scrap_rate, :decimal)

    belongs_to(:parent_material, HexaFactory.Domain.Material)
    belongs_to(:component_material, HexaFactory.Domain.Material)

    timestamps()
  end
end
