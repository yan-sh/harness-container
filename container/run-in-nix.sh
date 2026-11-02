#!/usr/bin/env bash
set -euo pipefail

nix_bin_dir="${HC_NIX_BIN_DIR:-/nix/.harness-container-bin}"
command=("$@")

if [ -n "${HC_NIX_PACKAGES:-}" ]; then
  packages=()
  while IFS= read -r package; do
    [ -z "$package" ] || packages+=("$package")
  done <<< "$HC_NIX_PACKAGES"
  command=("$nix_bin_dir/nix" shell "${packages[@]}" --command "${command[@]}")
fi

if [ -f flake.nix ]; then
  exec "$nix_bin_dir/nix" develop . --command "${command[@]}"
fi

expression=""
if [ -f shell.nix ]; then
  expression=./shell.nix
elif [ -f default.nix ]; then
  expression=./default.nix
fi

if [ -n "$expression" ]; then
  printf -v quoted '%q ' "${command[@]}"
  exec "$nix_bin_dir/nix-shell" "$expression" --run "exec ${quoted% }"
fi

exec "${command[@]}"
