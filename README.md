# Harness container

Run Claude Code, Codex, OpenCode or Pi in a Linux container with the current directory and the harness's user data mounted from the host.

## Requirements

- Python 3.11 or newer.
- Docker or Podman with a running Linux container engine.

On macOS, automatic runtime selection tries Docker and then Podman. On Linux it tries Podman and then Docker. On Windows it uses Docker Desktop; running the script in WSL 2 is also supported.

On native Windows, invoke the script with `py -3.11 run-harness` from PowerShell. In WSL 2, use the shell command shown below.

## Start

Put a `harness.toml` in the directory you want to mount (this repository includes a starter file), select a harness, then run:

```sh
/path/to/harness-container/run-harness
```

The whole launch directory is mounted at `/<directory-name>` by default. For example, running in `/work/my-app` opens the harness in `/my-app` inside the container. Extra arguments after `--` are passed to the selected harness:

```sh
/path/to/harness-container/run-harness -- --version
```

Use `--config /path/to/config.toml` to read another config file. `--dry-run` prints the first installed runtime in the configured priority order, mounts and container command without creating directories, building an image or starting a container. A real launch also checks that the engine is running and may select the next runtime. `--rebuild` refreshes the internal image, including the selected harness CLI.

## Configuration

The public configuration is shown in [`harness.toml.example`](harness.toml.example). The selected harness determines which host paths are mounted under `/home/agent`:

| Harness | Host paths |
| --- | --- |
| `claude` | `~/.claude`, `~/.claude.json` |
| `codex` | `~/.codex` |
| `opencode` | `~/.config/opencode`, `~/.local/share/opencode` |
| `pi` | `~/.pi` |

Missing standard state paths are created on first launch. `harness.state.paths` replaces the standard list; these paths must be inside the host home directory. The workspace and harness state mounts are writable. Additional `[[mounts]]` are read-only unless `mode = "rw"` is set. Relative extra mount paths are resolved from the config file's directory. Available path variables are `${HOME}`, `${CWD}`, `${CONFIG_DIR}` and `${CONTAINER_PLATFORM}`.

The container runs the harness with the host user's numeric UID and GID, so files it creates in mounted directories have the expected ownership. Codex credentials kept in the host OS keyring are not present in the container merely because `~/.codex` is mounted; sign in inside the container or use file-backed credentials.

## Nix

Set `software.nix.enabled = true` and choose a `store_dir` on the host. The directory is mounted at `/nix`. On first use, the launcher installs the configured Nix version into it; later runs reuse it. `software.nix.packages` are supplied through `nix shell` when the harness starts. The Nix settings table is passed to Nix as `NIX_CONFIG`.

Use a separate `store_dir` for each container architecture. A directory initialized for a different architecture or Nix version is rejected. The store must be writable by the host UID/GID used inside the container. Do not point it at the host's native Nix installation; the container needs a Linux store. The initial installation and package downloads require network access.

The listed packages are made available through `nix shell` on each launch; their downloaded store objects persist in `store_dir`. Pin a Nixpkgs revision in package references if you need the exact same package version on later launches. User profile changes made manually with `nix profile` inside a container are not covered by this persistence scheme.

When Nix is enabled, the launcher checks the mounted workspace in this order: `flake.nix` → `shell.nix` → `default.nix`. It uses `nix develop` for a flake and `nix-shell` for either legacy expression. The configured `packages` are added inside the selected project environment. Without a project Nix file, the launcher uses `nix shell` only for the configured packages.

## Limits

The image is built locally on first use, so that run requires network access. The tool uses the current upstream harness packages when the image is built; run `--rebuild` to refresh them. Mounting a host directory gives the harness write access to it when the mount is writable. The launcher does not mount the Docker socket.
