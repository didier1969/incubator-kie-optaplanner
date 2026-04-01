# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Domain.Resource do
  @moduledoc "A generic scheduling resource carried as a plain data contract."

  @enforce_keys []
  defstruct [
    :id,
    :name,
    capacity: 1,
    availability_windows: []
  ]

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          capacity: integer(),
          availability_windows: list(HexaCore.Domain.Window.t())
        }
end
