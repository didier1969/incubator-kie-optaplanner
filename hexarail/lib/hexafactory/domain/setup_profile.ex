# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.SetupProfile do
  @moduledoc "Setup family or thermal profile used by setup transitions."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_setup_profiles" do
    field(:code, :string)
    field(:description, :string)

    timestamps()
  end
end
