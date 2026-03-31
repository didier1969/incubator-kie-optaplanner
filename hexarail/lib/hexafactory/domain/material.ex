# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.Material do
  @moduledoc "Material master record used by orders, BOMs, and transport lanes."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_materials" do
    field(:code, :string)
    field(:description, :string)
    field(:material_type, :string)
    field(:base_uom, :string)

    timestamps()
  end
end
