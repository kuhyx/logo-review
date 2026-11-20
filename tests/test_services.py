"""Service logos: fetched from a fake local source (no network), written whole or not at all, served by known id only."""

from __future__ import annotations

import json
import os
import struct
import threading
import zlib
from http.server import ThreadingHTTPServer
from pathlib import Path

import fake_icons
import pytest
from test_server import get, project, serve  # noqa: F401 (pytest fixture)

import server
import services

TWO = ("signal", "discord")


def png_size(data: bytes) -> tuple[int, int]:
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    return struct.unpack(">II", data[16:24])


def png_has_ink(data: bytes) -> bool:
    """Whether any pixel is not fully transparent (8-bit RGBA, rows unfiltered by hand)."""
    width, height = png_size(data)
    assert data[24:26] == b"\x08\x06", "8-bit RGBA"
    idat, at = b"", 8
    while at < len(data):
        length, kind = struct.unpack(">I4s", data[at : at + 8])
        if kind == b"IDAT":
            idat += data[at + 8 : at + 8 + length]
        at += 12 + length
    raw, stride, prev = zlib.decompress(idat), width * 4, bytearray(width * 4)
    for y in range(height):
        kind, row = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1 : (y + 1) * (stride + 1)])
        for x in range(stride):
            a = row[x - 4] if x >= 4 else 0
            b, c = prev[x], prev[x - 4] if x >= 4 else 0
            if kind == 1:
                row[x] = (row[x] + a) & 255
            elif kind == 2:
                row[x] = (row[x] + b) & 255
            elif kind == 3:
                row[x] = (row[x] + (a + b) // 2) & 255
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                row[x] = (row[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        if any(row[3::4]):
            return True
        prev = row
    return False


@pytest.fixture
def source(tmp_path: Path) -> str:
    return (fake_icons.write(tmp_path / "cdn").as_uri()) + "/"


def test_the_manifest_lists_every_service_with_url_licence_and_hex() -> None:
    manifest = services.load_manifest()
    assert manifest["version"] == services.VERSION
    assert sorted(manifest["services"]) == sorted(services.IDS) and len(services.IDS) == 14
    for sid, entry in manifest["services"].items():
        assert entry["url"] == f"{services.CDN}icons/{entry['slug']}.svg", sid
        assert entry["url"].startswith("https://cdn.jsdelivr.net/npm/simple-icons@")
        assert "CC0" in entry["licence"] and "trademark" in entry["licence"], sid
        assert len(entry["hex"]) == 6 and int(entry["hex"], 16) >= 0, sid


def test_a_fetch_writes_a_brand_coloured_svg_and_a_1024_png(source: str, tmp_path: Path) -> None:
    if services.browser() is None:
        pytest.skip("no chromium to render with")
    dest = tmp_path / "out"
    assert services.fetch_all(dest, base=source, ids=TWO) == []
    hexes = services.load_manifest()["services"]
    for sid in TWO:
        svg = (dest / f"{sid}.svg").read_text()
        assert f'fill="#{hexes[sid]["hex"]}"' in svg and "<script" not in svg
        png = (dest / f"{sid}.png").read_bytes()
        assert png_size(png) == (1024, 1024)
        assert png_has_ink(png), f"{sid}.png is blank"


def test_without_a_browser_only_the_svg_is_written(source: str, tmp_path: Path) -> None:
    dest = tmp_path / "out"
    assert services.fetch_all(dest, base=source, ids=TWO, chromium=None) == []
    assert (dest / "signal.svg").exists() and not (dest / "signal.png").exists()


def test_a_failed_fetch_leaves_no_partial_file(tmp_path: Path) -> None:
    dest = tmp_path / "out"
    missing = services.fetch_all(dest, base=(tmp_path / "nothing").as_uri() + "/", ids=TWO, chromium=None)
    assert missing == list(TWO)
    assert not dest.exists() or list(dest.iterdir()) == []


def test_an_svg_that_is_not_one_plain_path_is_refused(tmp_path: Path) -> None:
    root = fake_icons.write(tmp_path / "cdn", ("signal",))
    (root / "icons/signal.svg").write_text('<svg><script>alert(1)</script><path d="M0 0z"/></svg>')
    dest = tmp_path / "out"
    assert services.fetch_all(dest, base=root.as_uri() + "/", ids=("signal",), chromium=None) == ["signal"]
    assert not (dest / "signal.svg").exists()


def test_present_files_are_not_fetched_again(source: str, tmp_path: Path) -> None:
    dest = tmp_path / "out"
    services.fetch_all(dest, base=source, ids=TWO, chromium=None)
    before = {f.name: f.stat().st_mtime_ns for f in dest.iterdir()}
    # The source is gone: a second run that fetched would fail.
    assert services.fetch_all(dest, base=(tmp_path / "gone").as_uri() + "/", ids=TWO, chromium=None) == []
    assert {f.name: f.stat().st_mtime_ns for f in dest.iterdir()} == before


def test_only_the_pinned_host_or_a_local_mirror_is_a_source() -> None:
    assert services.check_source(services.CDN) == services.CDN
    assert services.check_source("file:///tmp/x") == "file:///tmp/x/"
    with pytest.raises(ValueError):
        services.check_source("https://evil.example/")


def test_the_server_serves_known_ids_only(project: Path, tmp_path: Path, source: str) -> None:  # noqa: F811
    dest = tmp_path / "logos"
    services.fetch_all(dest, base=source, ids=("signal",), chromium=None)
    (tmp_path / "secret.svg").write_text("<svg/>")
    handler = server.make_handler(server.Project(project), tmp_path / "state", services_dir=dest)
    httpd = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    status, body, headers = get(httpd, "/services/signal.svg")
    assert status == 200 and headers["Content-Type"] == "image/svg+xml" and body.startswith(b"<svg")
    assert get(httpd, "/services/signal.png")[0] == 404, "not rendered: no file"
    assert get(httpd, "/services/discord.svg")[0] == 404, "known, not fetched yet"
    for path in ("/services/nope.png", "/services/../server.py", "/services/%2e%2e/secret.svg", "/services/../secret.svg"):
        assert get(httpd, path)[0] == 404, path


@pytest.mark.skipif(not os.environ.get("LOGO_REVIEW_NETWORK"), reason="network test: set LOGO_REVIEW_NETWORK=1")
def test_the_real_urls_answer(tmp_path: Path) -> None:
    assert services.fetch_all(tmp_path, chromium=None) == []
    assert json.loads(json.dumps(sorted(p.name for p in tmp_path.glob("*.svg")))) == sorted(f"{s}.svg" for s in services.IDS)
