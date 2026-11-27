"""emulator_apk.sh: one staged step per call, pointed at a test server, never the phone."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "emulator_apk.sh"


def run(tmp_path: Path, *args: str, serial: str = "emulator-5554", rc: int = 0) -> subprocess.CompletedProcess:
    fake = tmp_path / "phone_deploy.sh"
    fake.write_text(f'#!/bin/bash\necho "args: $*"\nsleep 1\necho "build lock taken after 1 s"\nsleep 1\nexit {rc}\n')
    fake.chmod(0o755)
    env = {**os.environ, "ADB_SERIAL": serial, "PHONE_DEPLOY": str(fake)}
    return subprocess.run([SCRIPT, *args], env=env, capture_output=True, text=True, timeout=10, check=False)


def test_prep_passes_the_test_server_url_and_prints_its_seconds(tmp_path: Path) -> None:
    proc = run(tmp_path, "prep", "19414")
    assert proc.returncode == 0, proc.stderr
    assert f"args: {ROOT}/app --stage prep --dart-define LOGO_REVIEW_URL=http://10.0.2.2:19414" in proc.stdout
    assert "prep: wait 1 s, build 1 s" in proc.stdout


def test_later_stage_without_port_reuses_what_prep_saved(tmp_path: Path) -> None:
    proc = run(tmp_path, "dart")
    assert proc.returncode == 0, proc.stderr
    assert f"args: {ROOT}/app --stage dart\n" in proc.stdout


def test_a_failed_stage_keeps_its_exit_code_and_still_prints_seconds(tmp_path: Path) -> None:
    proc = run(tmp_path, "assemble", rc=34)
    assert proc.returncode == 34
    assert "assemble: wait 1 s" in proc.stdout


def test_prep_without_port_is_refused(tmp_path: Path) -> None:
    proc = run(tmp_path, "prep")
    assert proc.returncode == 2
    assert "args:" not in proc.stdout


def test_the_phone_is_refused(tmp_path: Path) -> None:
    proc = run(tmp_path, "dart", serial="23181JEGR08034")
    assert proc.returncode == 2
    assert "args:" not in proc.stdout


def test_unknown_stage_is_refused(tmp_path: Path) -> None:
    assert run(tmp_path, "build", "1").returncode == 2
