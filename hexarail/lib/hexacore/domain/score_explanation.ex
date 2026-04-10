# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Domain.ScoreExplanation do
  @moduledoc """
  Holds the final score and the list of violated constraints for XAI.
  """

  @enforce_keys [:score, :violations]
  defstruct [:score, :violations]

  @type t :: %__MODULE__{
          score: HexaCore.Domain.HardMediumSoftScore.t(),
          violations: list(HexaCore.Domain.ConstraintViolation.t())
        }
end
