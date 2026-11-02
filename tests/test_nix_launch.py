"""Check project Nix environment selection without a container engine."""

from pathlib import Path
import os
import subprocess
import tempfile
import unittest


LAUNCHER = Path(__file__).resolve().parents[1] / "container" / "run-in-nix.sh"


class NixLaunchTests(unittest.TestCase):
    def run_case(self, files: tuple[str, ...], packages: str = "") -> tuple[list[str], str, list[str]]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binaries = root / "bin"
            workspace = root / "workspace"
            binaries.mkdir()
            workspace.mkdir()
            for name in files:
                (workspace / name).write_text("# test expression\n")

            nix = binaries / "nix"
            nix.write_text(
                "#!/usr/bin/env bash\n"
                "set -eu\n"
                "printf '%s\\n' \"$1\" >> \"$HC_TEST_MODES\"\n"
                "if [ \"$1\" = develop ]; then\n"
                "  [ \"$2\" = . ] && [ \"$3\" = --command ] || exit 3\n"
                "fi\n"
                "until [ \"$1\" = --command ]; do shift; done\n"
                "shift\n"
                "exec \"$@\"\n"
            )
            nix_shell = binaries / "nix-shell"
            nix_shell.write_text(
                "#!/usr/bin/env bash\n"
                "set -eu\n"
                "[ \"$2\" = --run ] || exit 3\n"
                "printf '%s\\n' \"$1\" > \"$HC_TEST_EXPRESSION\"\n"
                "exec bash -c \"$3\"\n"
            )
            harness = binaries / "test-harness"
            harness.write_text(
                "#!/usr/bin/env bash\n"
                "printf '%s\\0' \"$@\" > \"$HC_TEST_ARGS\"\n"
            )
            for path in (nix, nix_shell, harness):
                path.chmod(0o755)

            environment = os.environ.copy()
            environment.update(
                PATH=str(binaries) + os.pathsep + environment["PATH"],
                HC_NIX_BIN_DIR=str(binaries),
                HC_NIX_PACKAGES=packages,
                HC_TEST_MODES=str(root / "modes"),
                HC_TEST_EXPRESSION=str(root / "expression"),
                HC_TEST_ARGS=str(root / "args"),
            )
            result = subprocess.run(
                ["bash", str(LAUNCHER), "test-harness", "two words", "quote'and$space", ""],
                cwd=workspace,
                env=environment,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            modes = (root / "modes").read_text().splitlines() if (root / "modes").exists() else []
            expression = (root / "expression").read_text().strip() if (root / "expression").exists() else ""
            args = (root / "args").read_bytes().split(b"\0")[:-1]
            return modes, expression, [arg.decode() for arg in args]

    def test_flake_takes_priority_and_keeps_packages(self) -> None:
        modes, expression, args = self.run_case(("flake.nix", "shell.nix", "default.nix"), "nixpkgs#jq")
        self.assertEqual(modes, ["develop", "shell"])
        self.assertEqual(expression, "")
        self.assertEqual(args, ["two words", "quote'and$space", ""])

    def test_shell_nix_takes_priority_over_default(self) -> None:
        modes, expression, args = self.run_case(("shell.nix", "default.nix"))
        self.assertEqual(modes, [])
        self.assertEqual(expression, "./shell.nix")
        self.assertEqual(args, ["two words", "quote'and$space", ""])

    def test_default_nix_and_packages(self) -> None:
        modes, expression, args = self.run_case(("default.nix",), "nixpkgs#jq\nnixpkgs#git")
        self.assertEqual(modes, ["shell"])
        self.assertEqual(expression, "./default.nix")
        self.assertEqual(args, ["two words", "quote'and$space", ""])

    def test_without_project_file(self) -> None:
        modes, expression, args = self.run_case(())
        self.assertEqual(modes, [])
        self.assertEqual(expression, "")
        self.assertEqual(args, ["two words", "quote'and$space", ""])


if __name__ == "__main__":
    unittest.main()
