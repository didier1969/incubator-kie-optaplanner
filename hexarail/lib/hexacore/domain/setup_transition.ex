# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Domain.SetupTransition do
  @moduledoc """
  Defines the sequence-dependent setup time when transitioning between two group IDs.
  """

  @enforce_keys [:from_group, :to_group, :duration]
  defstruct [:from_group, :to_group, :duration]

  @type t :: %__MODULE__{
          from_group: String.t(),
          to_group: String.t(),
          duration: integer()
        }
end
