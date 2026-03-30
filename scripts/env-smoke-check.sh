#!/usr/bin/env bash
# Copyright (c) Didier Stadelmann. All rights reserved.

set -euo pipefail

ROOT_DIR="${1:-$PWD}"
STATE_DIR="$ROOT_DIR/.state"
FAILURES=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  FAILURES=$((FAILURES + 1))
}

expect_nix_tool() {
  local name="$1"
  local path

  path="$(command -v "$name" 2>/dev/null || true)"
  if [ -z "$path" ]; then
    fail "$name is missing from PATH"
    return
  fi

  case "$path" in
    /nix/store/*) ;;
    *)
      fail "$name does not come from the Nix shell: $path"
      ;;
  esac
}

expect_prefix() {
  local var_name="$1"
  local expected_prefix="$2"
  local actual="${!var_name:-}"

  if [ -z "$actual" ]; then
    fail "$var_name is not set"
    return
  fi

  case "$actual" in
    "$expected_prefix"*) ;;
    *)
      fail "$var_name should be under $expected_prefix but is $actual"
      ;;
  esac
}

expect_port() {
  local var_name="$1"
  local value="${!var_name:-}"

  if [ -z "$value" ]; then
    fail "$var_name is not set"
    return
  fi

  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    fail "$var_name is not numeric: $value"
    return
  fi

  if [ "$value" -lt 1024 ] || [ "$value" -gt 65535 ]; then
    fail "$var_name is out of range: $value"
  fi
}

if [ -z "${IN_NIX_SHELL:-}" ]; then
  fail "IN_NIX_SHELL is empty"
fi

expect_nix_tool mix
expect_nix_tool cargo
expect_nix_tool psql

expect_prefix MIX_HOME "$STATE_DIR"
expect_prefix HEX_HOME "$STATE_DIR"
expect_prefix CARGO_TARGET_DIR "$STATE_DIR"
expect_prefix PGDATA "$STATE_DIR"
expect_prefix PGHOST "$STATE_DIR"

expect_port HEXARAIL_PGPORT
expect_port HEXARAIL_WEB_PORT
expect_port HEXARAIL_TEST_PORT

if [ "$FAILURES" -gt 0 ]; then
  printf 'Environment smoke check failed with %s issue(s).\n' "$FAILURES" >&2
  exit 1
fi

printf 'Environment smoke check passed.\n'
