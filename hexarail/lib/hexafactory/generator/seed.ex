# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Generator.Seed do
  @moduledoc "Deterministic pseudo-random helper used by HexaFactory dataset builders."

  @type state :: :rand.state()

  @spec new(integer()) :: state()
  def new(seed) when is_integer(seed) do
    :rand.seed_s(:exsss, {seed, seed * 2 + 11, seed * 3 + 29})
  end

  @spec integer(state(), integer(), integer()) :: {integer(), state()}
  def integer(state, min, max) when min <= max do
    {value, next_state} = :rand.uniform_s(max - min + 1, state)
    {min + value - 1, next_state}
  end

  @spec pick(state(), [term()]) :: {term(), state()}
  def pick(state, values) when is_list(values) and values != [] do
    {index, next_state} = integer(state, 0, length(values) - 1)
    {Enum.at(values, index), next_state}
  end
end
