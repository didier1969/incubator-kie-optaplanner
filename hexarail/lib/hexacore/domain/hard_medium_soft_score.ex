# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Domain.HardMediumSoftScore do
  @moduledoc """
  Multi-level prioritized score.
  """

  @enforce_keys [:hard, :medium, :soft]
  defstruct [:hard, :medium, :soft]

  @type t :: %__MODULE__{
          hard: integer(),
          medium: integer(),
          soft: integer()
        }
end
