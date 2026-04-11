defmodule HexaFactory.PubSubBroadcastTest do
  use HexaRail.DataCase

  test "solver broadcasts results to simulation:hexafactory" do
    Phoenix.PubSub.subscribe(HexaRail.PubSub, "simulation:hexafactory")
    
    # Trigger a small solve. Smoke profile will insert initial data.
    HexaFactory.CLI.solve_dataset(HexaFactory.CLI.parse_common_opts(["--profile", "smoke", "--iterations", "10"]))
    
    assert_receive {:hexafactory_update, %{problem: _, explanation: _}}, 5000
  end
end