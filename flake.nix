{
  description = "HexaPlanner Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            erlang_26
            elixir_1_16
            cargo
            rustc
            rustfmt
            clippy
            # Required for Rustler C FFI compilation
            gcc
          ];

          shellHook = ''
            echo "HexaPlanner Dev Environment loaded."
            echo "Elixir $(elixir --version | grep Elixir)"
            echo "Rust $(cargo --version)"
          '';
        };
      }
    );
}
