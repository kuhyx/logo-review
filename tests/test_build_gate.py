"""check_no_oneshot_build.sh: no doc or script tells anyone to run a one-shot APK build.

A one-shot build of the app holds a build slot for over 60 s (79 s cold, 2026-11-27);
the staged `scripts/emulator_apk.sh` / `phone_deploy.sh --stage` calls each stay under it.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GATE = ROOT / "scripts" / "check_no_oneshot_build.sh"
BARE = "flutter " + "build apk --debug --dart-define=LOGO_REVIEW_URL=http://10.0.2.2:1"


def gate(directory: Path) -> subprocess.CompletedProcess:
    return subprocess.run([GATE, str(directory)], capture_output=True, text=True, timeout=10, check=False)


def scratch(tmp_path: Path) -> Path:
    copy = tmp_path / "repo"
    (copy / "scripts").mkdir(parents=True)
    for name in ("CLAUDE.md", "README.md", "DOCS-features.md", "run.sh", "run-check.sh"):
        shutil.copy(ROOT / name, copy / name)
    for script in (ROOT / "scripts").glob("*.sh"):
        shutil.copy(script, copy / "scripts" / script.name)
    return copy


def test_the_repo_passes() -> None:
    proc = gate(ROOT)
    assert proc.returncode == 0, proc.stderr


def test_a_bare_build_line_in_claude_md_fails_and_is_named(tmp_path: Path) -> None:
    copy = scratch(tmp_path)
    doc = copy / "CLAUDE.md"
    doc.write_text(doc.read_text() + f"- emulator: `{BARE}`\n")
    proc = gate(copy)
    assert proc.returncode == 1
    assert "CLAUDE.md" in proc.stderr and BARE in proc.stderr


def test_a_bare_build_in_a_script_fails(tmp_path: Path) -> None:
    copy = scratch(tmp_path)
    (copy / "scripts" / "x.sh").write_text(f"#!/bin/bash\nfvm {BARE}\n")
    proc = gate(copy)
    assert proc.returncode == 1
    assert "scripts/x.sh" in proc.stderr


def test_config_only_is_allowed(tmp_path: Path) -> None:
    copy = scratch(tmp_path)
    doc = copy / "CLAUDE.md"
    doc.write_text(doc.read_text() + "- `flutter " + "build apk --config-only`\n")
    assert gate(copy).returncode == 0


def test_a_missing_dir_fails_loudly(tmp_path: Path) -> None:
    proc = gate(tmp_path / "nope")
    assert proc.returncode == 2
    assert "nope" in proc.stderr
