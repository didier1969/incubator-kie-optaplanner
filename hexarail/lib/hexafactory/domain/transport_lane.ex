# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.TransportLane do
  @moduledoc "Deterministic inter-plant transport duration for a material flow."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_transport_lanes" do
    field(:transit_minutes, :integer)

    belongs_to(:material, HexaFactory.Domain.Material)
    belongs_to(:source_plant, HexaFactory.Domain.Plant)
    belongs_to(:target_plant, HexaFactory.Domain.Plant)

    timestamps()
  end
end
