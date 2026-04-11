# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Domain.Problem do
  @moduledoc "The root aggregate holding a generic scheduling problem."
  defstruct [:id, resources: [], jobs: [], edges: [], score_components: [], setup_transitions: [], explanation: nil]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          resources: list(HexaCore.Domain.Resource.t()),
          jobs: list(HexaCore.Domain.Job.t()),
          edges: list(HexaCore.Domain.Edge.t()),
          score_components: list(HexaCore.Domain.ScoreComponent.t()),
          setup_transitions: list(map()),
          explanation: HexaCore.Domain.ScoreExplanation.t() | nil
        }
end
