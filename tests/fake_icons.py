"""A stand-in for the simple-icons CDN: one plain shape per service, no brand marks.

Used by the tests and by run-check.sh, so neither touches the network.
Run: python3 tests/fake_icons.py <dir>    writes <dir>/icons/<slug>.svg for every service
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

import services  # noqa: E402 (needs the repo on the path first)

# A circle with a hole: filled area and transparent area, so a render is neither blank nor solid.
SHAPE = '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><title>{title}</title><path d="M12 2a10 10 0 1 0 0 20 10 10 0 1 0 0-20zm0 6a4 4 0 1 1 0 8 4 4 0 1 1 0-8z"/></svg>'


def write(root: Path, ids: tuple[str, ...] = services.IDS) -> Path:
    """Write the fake icons of `ids` under root/icons; return root."""
    entries = services.load_manifest()["services"]
    (root / "icons").mkdir(parents=True, exist_ok=True)
    for sid in ids:
        entry = entries[sid]
        (root / "icons" / f"{entry['slug']}.svg").write_text(SHAPE.format(title=entry["title"]))
    return root


if __name__ == "__main__":
    write(Path(sys.argv[1]))
