# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.Operator do
  @moduledoc "Human resource anchored to a plant and a primary skill."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_operators" do
    field(:code, :string)
    field(:name, :string)

    belongs_to(:primary_skill, HexaFactory.Domain.Skill)
    belongs_to(:home_plant, HexaFactory.Domain.Plant)

    timestamps()
  end
end
