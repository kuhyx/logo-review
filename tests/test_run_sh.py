"""run.sh: one command starts the tool on this computer for the project it remembers."""

from __future__ import annotations

import os
import socket
import subprocess
import urllib.request
from pathlib import Path

import pytest

from test_server import project  # noqa: F401 (fixture)

ROOT = Path(__file__).resolve().parents[1]
UNIT = "logo-review-runsh-test"


def run(env: dict, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run([ROOT / "run.sh", *args], env=env, capture_output=True, text=True, timeout=30, check=False)


@pytest.mark.skipif(subprocess.run(["systemctl", "--user", "is-system-running"], capture_output=True, check=False).returncode > 1, reason="no systemd user session")
def test_run_sh_starts_the_remembered_project_without_arguments(project: Path, tmp_path: Path) -> None:  # noqa: F811
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    env = {**os.environ, "XDG_CONFIG_HOME": str(tmp_path / "config"), "LOGO_REVIEW_UNIT": UNIT, "LOGO_REVIEW_PORT": str(port)}
    try:
        none = run(env, "--no-open")
        assert none.returncode != 0 and "project" in none.stderr, "with nothing remembered it says what it needs"
        first = run(env, str(project), "--no-open")
        assert first.returncode == 0, first.stderr
        assert f"http://127.0.0.1:{port}/" in first.stdout
        again = run(env, "--no-open")
        assert again.returncode == 0, again.stderr
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/api/manifest", timeout=5) as res:
            assert b'"round": 2' in res.read()
    finally:
        subprocess.run(["systemctl", "--user", "stop", UNIT], capture_output=True, check=False)
