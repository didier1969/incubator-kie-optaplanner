# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.StorageLocation do
  @moduledoc "Storage node for raw materials, buffers, and finished goods."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_storage_locations" do
    field(:code, :string)
    field(:name, :string)
    field(:kind, :string)

    belongs_to(:plant, HexaFactory.Domain.Plant)

    timestamps()
  end
end
