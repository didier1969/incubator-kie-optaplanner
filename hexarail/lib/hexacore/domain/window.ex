# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Domain.Window do
  @moduledoc "A generic availability or blackout interval expressed in planning ticks."

  @enforce_keys [:start_at, :end_at]
  defstruct [:start_at, :end_at]

  @type t :: %__MODULE__{
          start_at: integer(),
          end_at: integer()
        }
end
