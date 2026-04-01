# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.RoutingOperation do
  @moduledoc "One ordered operation inside a routing alternative."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_routing_operations" do
    field(:sequence, :integer)
    field(:operation_kind, :string)
    field(:batchable, :boolean, default: false)
    field(:transfer_batch_size, :integer)

    belongs_to(:routing, HexaFactory.Domain.Routing)

    timestamps()
  end
end
