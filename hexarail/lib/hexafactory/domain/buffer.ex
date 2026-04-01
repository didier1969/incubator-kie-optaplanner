# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.Buffer do
  @moduledoc "Finite intermediate storage capacity attached to a plant."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_buffers" do
    field(:code, :string)
    field(:capacity_units, :integer)
    field(:material_type, :string)

    belongs_to(:plant, HexaFactory.Domain.Plant)

    timestamps()
  end
end
