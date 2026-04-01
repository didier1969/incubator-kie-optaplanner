# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.Routing do
  @moduledoc "Alternative routing header for one material in one plant."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_routings" do
    field(:code, :string)
    field(:alternative_kind, :string)

    belongs_to(:plant, HexaFactory.Domain.Plant)
    belongs_to(:material, HexaFactory.Domain.Material)
    has_many(:operations, HexaFactory.Domain.RoutingOperation)

    timestamps()
  end
end
