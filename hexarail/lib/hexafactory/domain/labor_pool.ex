# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.LaborPool do
  @moduledoc "Pool of labor capacity assigned to a plant or an industrial area."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_labor_pools" do
    field(:code, :string)
    field(:name, :string)

    belongs_to(:plant, HexaFactory.Domain.Plant)

    timestamps()
  end
end
