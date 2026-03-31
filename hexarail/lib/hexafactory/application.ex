# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Application do
  @moduledoc "HexaFactory vertical entrypoint."

  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([], strategy: :one_for_one, name: __MODULE__.Supervisor)
  end
end
