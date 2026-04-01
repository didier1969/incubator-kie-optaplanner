# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.BatchPolicy do
  @moduledoc "Batch sizing rule attached to an operation family."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_batch_policies" do
    field(:code, :string)
    field(:operation_kind, :string)
    field(:min_batch_size, :integer)
    field(:max_batch_size, :integer)
    field(:mix_key, :string)

    timestamps()
  end
end
