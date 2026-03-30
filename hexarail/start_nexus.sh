#!/usr/bin/env bash
# Copyright (c) Didier Stadelmann. All rights reserved.

set -euo pipefail

PORT="${HEXARAIL_WEB_PORT:-${PORT:-14326}}"

echo "[NEXUS] Starting System Initialization..."

# 1. Clean up dangling processes safely and specifically
echo "[NEXUS] Hunting for dangling HexaRail processes..."

# Strategy A: Kill BEAM processes whose Current Working Directory is the hexarail folder
# This ensures we NEVER kill other Elixir projects on the same machine.
HEXA_DIR=$(pwd)
BEAM_PIDS=$(lsof -a -d cwd -c beam.smp 2>/dev/null | grep "$HEXA_DIR" | awk '{print $2}' | sort -u || true)

if [ ! -z "$BEAM_PIDS" ]; then
  echo "[NEXUS] Terminating dangling PIDs safely: $BEAM_PIDS"
  kill -9 $BEAM_PIDS 2>/dev/null || true
else
  echo "[NEXUS] No directory-bound dangling processes found."
fi

# Strategy B: Free the specific TCP port
PORT_PIDS=$(lsof -t -i :"$PORT" 2>/dev/null || true)
if [ ! -z "$PORT_PIDS" ]; then
  echo "[NEXUS] Freeing port $PORT (PIDs: $PORT_PIDS)..."
  kill $PORT_PIDS 2>/dev/null || true
  sleep 1
fi

# 2. Compile and build
echo "[NEXUS] Compiling System..."
export MIX_ENV=dev
mix deps.get
mix compile

# 3. Start the Server
echo "[NEXUS] Igniting Tick Engine on Port $PORT..."
export PORT
exec mix phx.server
