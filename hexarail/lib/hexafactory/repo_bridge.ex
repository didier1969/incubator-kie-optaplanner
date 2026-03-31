# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.RepoBridge do
  @moduledoc "Thin bridge exposing the shared repository to the HexaFactory vertical."

  alias HexaRail.Repo

  @spec repo() :: module()
  def repo, do: Repo
end
