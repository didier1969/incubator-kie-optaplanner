{
  description = "HexaRail Development Environment";

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
            erlang_27
            elixir_1_19
            cargo
            rustc
            rustfmt
            clippy
            gcc
            unzip
            tippecanoe
            (postgresql_15.withPackages (p: [ p.postgis ]))
          ];

          shellHook = ''
            echo "HexaRail Dev Environment loaded."
            echo "Elixir $(elixir --version | grep Elixir)"
            echo "Rust $(cargo --version)"
            
            # Setup local Postgres for development inside the workspace
            export PGDATA=$PWD/.pgdata
            export PGHOST=$PWD/.pgdata
            
            if [ ! -d $PGDATA ]; then
              echo "Initializing local PostgreSQL database at $PGDATA..."
              initdb -U postgres --auth=trust >/dev/null
            fi
            
            if ! pg_isready -q; then
              echo "Starting local PostgreSQL server..."
              pg_ctl start -l $PGDATA/pg.log -o "-p 15432 -c unix_socket_directories=$PWD/.pgdata" >/dev/null
            fi
            
            # Ensure proper stop on exit
            trap 'pg_ctl stop -m fast >/dev/null 2>&1' EXIT
          '';
        };
      }
    );
}
