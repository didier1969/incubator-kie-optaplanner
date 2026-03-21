defmodule HexaPlanner.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias HexaPlanner.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import HexaPlanner.DataCase
    end
  end

  setup tags do
    HexaPlanner.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(HexaPlanner.Repo, shared: not tags[:async])
    ExUnit.Callbacks.on_exit(fn -> Sandbox.stop_owner(pid) end)
  end
end
