# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule Mix.Tasks.Hexarail.SmokeTaskTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  setup do
    Mix.Task.reenable("hexarail.smoke")
    :ok
  end

  test "smoke task prints a usable railway summary" do
    output =
      capture_io(fn ->
        Mix.Task.run("hexarail.smoke", [
          "--strategy",
          "greedy",
          "--query-time",
          "150"
        ])
      end)

    assert output =~ "HexaRail smoke"
    assert output =~ "strategy=greedy"
    assert output =~ "tracks=1"
    assert output =~ "active_before=2"
    assert output =~ "active_after=0"
    assert output =~ "resolution_status=success"
  end
end
