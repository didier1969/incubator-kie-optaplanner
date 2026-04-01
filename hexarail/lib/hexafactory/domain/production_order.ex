# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.ProductionOrder do
  @moduledoc "Executable manufacturing order released against a plant and material."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_production_orders" do
    field(:order_code, :string)
    field(:quantity, :integer)
    field(:priority, :integer)

    belongs_to(:plant, HexaFactory.Domain.Plant)
    belongs_to(:material, HexaFactory.Domain.Material)

    timestamps()
  end
end
