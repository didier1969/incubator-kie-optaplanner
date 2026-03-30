# Copyright (c) Didier Stadelmann. All rights reserved.

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
          packages = with pkgs; [
            erlang_27
            elixir_1_19
            cargo
            rustc
            rustfmt
            clippy
            gcc
            python3
            unzip
            tippecanoe
            gdal
            (postgresql_15.withPackages (p: [ p.postgis ]))
          ];

          shellHook = ''
            echo "HexaRail Dev Environment loaded."
            echo "Elixir $(elixir --version | grep Elixir)"
            echo "Rust $(cargo --version)"

            export HEXARAIL_STATE_DIR="$PWD/.state"
            export MIX_HOME="$HEXARAIL_STATE_DIR/mix-home"
            export HEX_HOME="$HEXARAIL_STATE_DIR/hex-home"
            export CARGO_TARGET_DIR="$HEXARAIL_STATE_DIR/cargo-target"
            export PGDATA="$HEXARAIL_STATE_DIR/postgres"
            export PGHOST="$HEXARAIL_STATE_DIR/postgres"
            export PGPASSWORD="postgres_password"
            export ERL_AFLAGS="-kernel shell_history enabled"

            mkdir -p "$HEXARAIL_STATE_DIR" "$MIX_HOME" "$HEX_HOME" "$CARGO_TARGET_DIR"

            PORTS_FILE="$HEXARAIL_STATE_DIR/ports.env"
            if [ ! -f "$PORTS_FILE" ]; then
              python3 <<'PY' > "$PORTS_FILE"
import socket

def reserve_port():
    sock = socket.socket()
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]
    sock.close()
    return port

print(f"export HEXARAIL_PGPORT={reserve_port()}")
print(f"export HEXARAIL_WEB_PORT={reserve_port()}")
print(f"export HEXARAIL_TEST_PORT={reserve_port()}")
PY
            fi

            . "$PORTS_FILE"
            export PORT="$HEXARAIL_WEB_PORT"

            if ! mix hex.info >/dev/null 2>&1; then
              mix local.hex --force >/dev/null 2>&1 || true
            fi

            mix local.rebar --force >/dev/null 2>&1 || true

            if [ ! -f "$PGDATA/PG_VERSION" ]; then
              echo "Initializing local PostgreSQL database at $PGDATA..."
              initdb -D "$PGDATA" -U postgres --auth=trust >/dev/null
            fi

            HEXARAIL_STARTED_PG=0
            if ! pg_ctl status -D "$PGDATA" >/dev/null 2>&1; then
              echo "Starting local PostgreSQL server on port $HEXARAIL_PGPORT..."
              pg_ctl start -D "$PGDATA" -l "$HEXARAIL_STATE_DIR/postgres.log" -o "-p $HEXARAIL_PGPORT -c unix_socket_directories=$PGHOST" >/dev/null
              HEXARAIL_STARTED_PG=1
            fi

            export HEXARAIL_STARTED_PG
            trap 'if [ "''${HEXARAIL_STARTED_PG:-0}" = "1" ]; then pg_ctl stop -D "$PGDATA" -m fast >/dev/null 2>&1 || true; fi' EXIT

            echo "Ports: web=$HEXARAIL_WEB_PORT test=$HEXARAIL_TEST_PORT postgres=$HEXARAIL_PGPORT"
          '';
        };
      }
    );
}
