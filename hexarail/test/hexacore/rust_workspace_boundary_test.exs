# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.RustWorkspaceBoundaryTest do
  use ExUnit.Case, async: true

  @workspace_file Path.expand("../../native/Cargo.toml", __DIR__)
  @workspace_lock_file Path.expand("../../native/Cargo.lock", __DIR__)
  @core_lock_file Path.expand("../../native/hexacore_engine/Cargo.lock", __DIR__)
  @rail_lock_file Path.expand("../../native/hexarail_engine/Cargo.lock", __DIR__)
  @core_native_file Path.expand("../../lib/hexacore/native.ex", __DIR__)
  @rail_native_file Path.expand("../../lib/hexarail/native.ex", __DIR__)

  test "rust crates share a workspace lockfile and target dir" do
    assert File.exists?(@workspace_file)
    assert File.exists?(@workspace_lock_file)
    refute File.exists?(@core_lock_file)
    refute File.exists?(@rail_lock_file)

    workspace_source = File.read!(@workspace_file)
    assert workspace_source =~ "[workspace]"
    assert workspace_source =~ ~s("hexacore_engine")
    assert workspace_source =~ ~s("hexarail_engine")

    core_native_source = File.read!(@core_native_file)
    rail_native_source = File.read!(@rail_native_file)

    assert core_native_source =~ ~s(path: "native/hexacore_engine")
    assert rail_native_source =~ ~s(path: "native/hexarail_engine")
    assert core_native_source =~ "target_dir: Path.expand(\"native/target\", File.cwd!())"
    assert rail_native_source =~ "target_dir: Path.expand(\"native/target\", File.cwd!())"
  end
end
