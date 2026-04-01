# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule Mix.Tasks.Hexafactory.SmokeTaskTest do
  use HexaRail.DataCase, async: false

  import ExUnit.CaptureIO

  setup do
    Mix.Task.reenable("hexafactory.smoke")
    :ok
  end

  test "smoke task runs the reduced-volume industrial path and prints a usable summary" do
    output =
      capture_io(fn ->
        Mix.Tasks.Hexafactory.Smoke.run([
          "--profile",
          "volumetry_smoke",
          "--seed",
          "2026",
          "--iterations",
          "64"
        ])
      end)

    assert output =~ "HexaFactory smoke"
    assert output =~ "profile=volumetry_smoke"
    assert output =~ "plants=4"
    assert output =~ "machines=20"
    assert output =~ "late_jobs="
  end
end
