#!/usr/bin/env bash
set -euo pipefail

if [ "${HC_NIX_ENABLED:-0}" != 1 ]; then
  exec "$@"
fi

if [ ! -d /nix ]; then
  echo "Nix store is not mounted at /nix" >&2
  exit 2
fi

if [ ! -w /nix ]; then
  echo "Nix store is not writable by the container user" >&2
  exit 2
fi

exec 9>/nix/.harness-container-lock
flock 9

expected="${HC_NIX_VERSION:-}"
installed=""
if [ -f /nix/.harness-container-version ]; then
  installed="$(cat /nix/.harness-container-version)"
fi

if [ -n "$installed" ] && [ "$installed" != "$expected" ]; then
  echo "Nix store was initialized with version $installed, requested $expected" >&2
  exit 2
fi

if [ -x /nix/.harness-container-bin/nix ] && { [ -z "$installed" ] || [ ! -f /nix/.harness-container-platform ]; }; then
  echo "Nix directory has an incomplete launcher installation" >&2
  exit 2
fi

if [ -f /nix/.harness-container-platform ] && [ "$(cat /nix/.harness-container-platform)" != "${HC_PLATFORM:-}" ]; then
  echo "Nix store belongs to a different container platform" >&2
  exit 2
fi

if [ ! -x /nix/.harness-container-bin/nix ]; then
  if [ -n "$(find /nix -mindepth 1 -maxdepth 1 ! -name .harness-container-lock -print -quit)" ]; then
    echo "Nix directory is not empty and was not initialized by this script" >&2
    exit 2
  fi
  echo "Installing Nix $expected into /nix..." >&2
  export NIX_INSTALLER_NO_MODIFY_PROFILE=1
  installer="$(mktemp)"
  trap 'rm -f "$installer"' EXIT
  curl -fsSL "https://releases.nixos.org/nix/nix-${expected}/install" -o "$installer"
  bash "$installer" --no-daemon
  rm -f "$installer"
  trap - EXIT
  mkdir -p /nix/.harness-container-bin
  nix_bin=""
  if [ -x "$HOME/.nix-profile/bin/nix" ]; then
    nix_bin="$HOME/.nix-profile/bin/nix"
  elif [ -x /nix/var/nix/profiles/default/bin/nix ]; then
    nix_bin=/nix/var/nix/profiles/default/bin/nix
  fi
  if [ -z "$nix_bin" ]; then
    echo "Nix installer completed, but the nix executable was not found" >&2
    exit 2
  fi
  ln -s "$(readlink -f "$nix_bin")" /nix/.harness-container-bin/nix
  printf '%s\n' "$expected" > /nix/.harness-container-version
  printf '%s\n' "${HC_PLATFORM:-}" > /nix/.harness-container-platform
fi

if [ ! -x /nix/.harness-container-bin/nix-shell ]; then
  nix_shell="$(dirname "$(readlink -f /nix/.harness-container-bin/nix)")/nix-shell"
  if [ ! -x "$nix_shell" ]; then
    echo "The Nix installation does not contain nix-shell" >&2
    exit 2
  fi
  ln -s "$nix_shell" /nix/.harness-container-bin/nix-shell
fi

flock -u 9
export PATH="/nix/.harness-container-bin:$PATH"

if [ -n "${HC_NIX_CONFIG:-}" ]; then
  export NIX_CONFIG="$HC_NIX_CONFIG"
fi

exec /usr/local/bin/harness-run-in-nix "$@"
