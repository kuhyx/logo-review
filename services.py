"""Service logos: one real mark per avatar service, the frame badge of the context previews.

The marks come from simple-icons at one pinned version on one CDN host: square, mark only, one colour.
assets/services/manifest.json (committed, made by `python3 services.py manifest`) lists each service's
slug, title, brand hex, source URL and licence note. At start the server fetches what is missing into
assets/services/ (gitignored: brand files stay out of the public repo):

  <id>.svg   the mark filled with its brand hex, rebuilt from the source's one path (nothing else kept)
  <id>.png   that SVG at 1024 x 1024 on transparent, rendered by headless Chromium (skipped without one)

Every file is written beside its target and renamed into place, so a failed fetch leaves nothing half-written.
Files already present are not fetched again. A bump of VERSION is its own change: rerun `manifest`.

Run: python3 services.py manifest   rewrite the manifest from the pinned version's data
     python3 services.py fetch      fetch what is missing now (what the server does at start)
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
# 13.21.0 is the newest simple-icons with all 14: LinkedIn left in 14.0.0, Slack in 16.0.0.
VERSION = "13.21.0"
CDN = f"https://cdn.jsdelivr.net/npm/simple-icons@{VERSION}/"
DIR = HERE / "assets" / "services"
MANIFEST = DIR / "manifest.json"
# id -> simple-icons title (the data file of this version has no slugs; the id is the slug).
TITLES = {
    "signal": "Signal", "discord": "Discord", "steam": "Steam", "linkedin": "LinkedIn", "facebook": "Facebook",
    "github": "GitHub", "whatsapp": "WhatsApp", "telegram": "Telegram", "instagram": "Instagram", "x": "X",
    "reddit": "Reddit", "youtube": "YouTube", "slack": "Slack", "gmail": "Gmail",
}  # fmt: skip
IDS = tuple(TITLES)
PNG_SIZE = 1024
PATH_RE = re.compile(rb'<path d="([0-9A-Za-z.,\- ]+)"\s*/>')
TIMEOUT = 20


def load_manifest(file: Path = MANIFEST) -> dict:
    return json.loads(file.read_text())


def check_source(base: str) -> str:
    """The pinned CDN, or a local mirror (tests, e2e); never any other host."""
    base = base.rstrip("/") + "/"
    if base != CDN and not base.startswith("file:///"):
        raise ValueError(f"not a logo source: {base}")
    return base


def _runs(path: str) -> bool:
    try:
        out = subprocess.run([path, "--version"], capture_output=True, text=True, timeout=20, check=False).stdout
    except (OSError, subprocess.SubprocessError):
        return False
    return any(ch.isdigit() for ch in out) and "invalid option" not in out


def browser() -> str | None:
    """A Chromium to render PNGs with, if this computer has one: the first on PATH whose --version works.

    A wrapper earlier on PATH can be broken (exits 0 but prints an exec error), so the probe checks
    that the output names a version, and walks every PATH entry rather than only the first match.
    """
    for name in ("chromium", "google-chrome-stable", "google-chrome"):
        for folder in os.environ.get("PATH", "").split(os.pathsep):
            path = shutil.which(name, path=folder)
            if path and _runs(path):
                return path
    return None


def _get(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=TIMEOUT) as res:
        return res.read()


def _put(target: Path, data: bytes) -> None:
    """Write beside the target, then rename: never half a file."""
    tmp = target.with_name(f".{target.name}.tmp")
    tmp.write_bytes(data)
    os.replace(tmp, target)


def clean_svg(raw: bytes, hex_colour: str) -> bytes:
    """The source's one path in a fresh SVG with the brand fill. Anything else in the source is dropped."""
    paths = PATH_RE.findall(raw)
    if len(paths) != 1 or b"<script" in raw.lower():
        raise ValueError("not a one-path icon")
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="{PNG_SIZE}" height="{PNG_SIZE}">'
            f'<path fill="#{hex_colour}" d="{paths[0].decode()}"/></svg>').encode()  # fmt: skip


def render_png(svg: Path, png: Path, chromium: str) -> None:
    """svg at 1024 x 1024 on transparent, through a throwaway headless Chromium profile.

    --no-sandbox: CI runners (Ubuntu 24.04) refuse Chromium's user-namespace sandbox. The page is ours and the
    SVG is the one path clean_svg kept, so nothing untrusted runs in it.
    """
    with tempfile.TemporaryDirectory(prefix="logo-render-") as work:
        page = Path(work) / "page.html"
        page.write_text(f'<!doctype html><style>html,body{{margin:0;background:transparent}}img{{display:block;width:{PNG_SIZE}px;height:{PNG_SIZE}px}}</style><img src="{svg.as_uri()}">')
        shot = Path(work) / "shot.png"
        subprocess.run(
            [chromium, "--headless=new", "--no-sandbox", f"--user-data-dir={work}/profile", "--no-first-run", "--disable-gpu", "--hide-scrollbars",
             "--allow-file-access-from-files", "--default-background-color=00000000", f"--window-size={PNG_SIZE},{PNG_SIZE}",
             f"--screenshot={shot}", page.as_uri()],
            capture_output=True, check=True, timeout=60, preexec_fn=lambda: os.nice(19),
        )  # fmt: skip
        _put(png, shot.read_bytes())


def fetch_svg(sid: str, dest: Path, base: str, entry: dict) -> bool:
    """Fetch one service's SVG unless present; True when it is there."""
    svg = dest / f"{sid}.svg"
    try:
        if not svg.exists():
            _put(svg, clean_svg(_get(f"{base}icons/{entry['slug']}.svg"), entry["hex"]))
    except (OSError, ValueError):
        return False
    return True


def render_missing(sid: str, dest: Path, chromium: str) -> bool:
    """Render one service's PNG from its SVG unless present; True when it is there."""
    png = dest / f"{sid}.png"
    try:
        if not png.exists():
            render_png(dest / f"{sid}.svg", png, chromium)
    except (OSError, subprocess.SubprocessError):
        return False
    return True


def fetch_all(dest: Path = DIR, base: str = CDN, ids: tuple[str, ...] = IDS, chromium: str | None | bool = True) -> list[str]:
    """Fetch every missing logo of `ids` into dest; returns the ids still missing. chromium=True: look one up.

    Every SVG first (seconds), then the PNGs (a Chromium start each, ~3 s): the page's badges need only the SVGs.
    """
    base = check_source(base)
    chromium = browser() if chromium is True else chromium or None
    entries = load_manifest()["services"]
    dest.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        have = [sid for sid, ok in zip(ids, pool.map(lambda sid: fetch_svg(sid, dest, base, entries[sid]), ids), strict=True) if ok]
    if chromium:
        # One render at a time, at the lowest priority: the computer stays responsive while they run.
        have = [sid for sid in have if render_missing(sid, dest, chromium)]
    return [sid for sid in ids if sid not in have]


def fetch_in_background(dest: Path = DIR, base: str = CDN) -> threading.Thread:
    """Fetch what is missing without holding up the server: one retry, then one line on stderr (the journal)."""

    def run() -> None:
        missing = fetch_all(dest, base) or fetch_all(dest, base)
        if missing:
            print(f"logo-review: service logos missing: {' '.join(missing)}", file=sys.stderr, flush=True)

    thread = threading.Thread(target=run, name="service-logos", daemon=True)
    thread.start()
    return thread


def build_manifest() -> dict:
    """The manifest from the pinned version's own data: brand hex and guidelines per service."""
    data = {icon["title"]: icon for icon in json.loads(_get(f"{CDN}_data/simple-icons.json"))["icons"]}
    entries = {}
    for sid, title in TITLES.items():
        icon = data[title]
        guide = icon.get("guidelines") or "none published"
        entries[sid] = {
            "slug": sid,
            "title": title,
            "hex": icon["hex"],
            "url": f"{CDN}icons/{sid}.svg",
            "licence": f"icon data CC0-1.0 (simple-icons {VERSION}); the mark is a trademark of its owner; guidelines: {guide}",
        }
    return {"source": "simple-icons", "version": VERSION, "services": entries}


if __name__ == "__main__":
    if sys.argv[1:] == ["manifest"]:
        _put(MANIFEST, (json.dumps(build_manifest(), indent=1, sort_keys=True) + "\n").encode())
    elif sys.argv[1:] == ["fetch"]:
        sys.exit(1 if fetch_all() else 0)
    else:
        sys.exit(__doc__)
