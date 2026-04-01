# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.SetupTransition do
  @moduledoc "Deterministic setup changeover duration between two setup profiles."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_setup_transitions" do
    field(:duration_minutes, :integer)

    belongs_to(:from_profile, HexaFactory.Domain.SetupProfile)
    belongs_to(:to_profile, HexaFactory.Domain.SetupProfile)

    timestamps()
  end
end
