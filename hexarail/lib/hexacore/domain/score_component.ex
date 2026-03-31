# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Domain.ScoreComponent do
  @moduledoc "A generic named score contribution produced by a vertical or the core."

  @enforce_keys [:name, :value]
  defstruct [:name, :value]

  @type t :: %__MODULE__{
          name: atom() | String.t(),
          value: integer()
        }
end
