"""Pairing a phone app through a public address: a short code from this computer, then a device key."""

from __future__ import annotations

import http.client
import json
import threading
from http.server import ThreadingHTTPServer
from pathlib import Path

import pairing
import server
from test_server import get, project  # noqa: F401 (fixture)

PUBLIC = {"Host": "logos.example.org"}


def serve(project: Path, data: Path, **kwargs):  # noqa: F811
    handler = server.make_handler(server.Project(project), data, public_url="https://logos.example.org/", **kwargs)
    httpd = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def post(httpd, path: str, body: object, headers: dict | None = None):
    conn = http.client.HTTPConnection("127.0.0.1", httpd.server_address[1], timeout=5)
    conn.request("POST", path, body=json.dumps(body), headers={"Content-Type": "application/json", **(headers or {})})
    res = conn.getresponse()
    return res.status, res.read()


def test_a_code_from_this_computer_pairs_a_device(project: Path, tmp_path: Path) -> None:  # noqa: F811
    httpd = serve(project, tmp_path / "state")
    assert get(httpd, "/api/manifest", PUBLIC)[0] == 403, "a proxied visitor has no key yet"
    assert post(httpd, "/api/pair/code", {}, PUBLIC)[0] == 403, "only this computer hands out codes"
    status, body = post(httpd, "/api/pair/code", {})
    code = json.loads(body)["code"]
    assert status == 200 and len(code) == 6 and code.isdigit()
    status, body = post(httpd, "/api/pair", {"code": code}, PUBLIC)
    token = json.loads(body)["token"]
    assert status == 200 and len(token) >= 32
    bearer = {**PUBLIC, "Authorization": f"Bearer {token}"}
    assert get(httpd, "/api/manifest", bearer)[0] == 200
    assert get(httpd, "/api/manifest", {**PUBLIC, "Authorization": "Bearer nope"})[0] == 403
    assert post(httpd, "/api/pair", {"code": code}, PUBLIC)[0] == 403, "a code works once"
    assert token not in (tmp_path / "state/devices.json").read_text(), "only the key's hash is kept"
    # The device stays paired across a restart.
    again = serve(project, tmp_path / "state")
    assert get(again, "/api/manifest", bearer)[0] == 200


def test_wrong_guesses_burn_the_code(project: Path, tmp_path: Path) -> None:  # noqa: F811
    httpd = serve(project, tmp_path / "state")
    code = json.loads(post(httpd, "/api/pair/code", {})[1])["code"]
    wrong = "000000" if code != "000000" else "111111"
    for _ in range(pairing.MAX_WRONG):
        assert post(httpd, "/api/pair", {"code": wrong}, PUBLIC)[0] == 403
    assert post(httpd, "/api/pair", {"code": code}, PUBLIC)[0] == 403, "guessing must not find the code"
    assert post(httpd, "/api/pair", "junk", PUBLIC)[0] == 403


def test_a_code_expires() -> None:
    now = [0.0]
    codes = pairing.PairCodes(clock=lambda: now[0])
    code = codes.mint()
    now[0] = pairing.CODE_TTL + 1
    assert not codes.redeem(code)
    assert len({codes.mint() for _ in range(pairing.MAX_PENDING + 3)}) >= 1 and len(codes.pending) == pairing.MAX_PENDING


def test_app_errors_land_in_the_spool(project: Path, tmp_path: Path) -> None:  # noqa: F811
    spool = tmp_path / "spool/logo-review.jsonl"
    httpd = serve(project, tmp_path / "state", errors=spool)
    entry = {"at": "2026-11-20T08:00:00Z", "kind": "uncaught.flutter", "error": "boom", "stack": ["a", "b"]}
    assert post(httpd, "/api/error", entry, PUBLIC)[0] == 403
    assert post(httpd, "/api/error", entry)[0] == 200
    assert post(httpd, "/api/error", ["not an entry"])[0] == 400
    assert json.loads(spool.read_text().splitlines()[0])["error"] == "boom"


def test_the_phone_link_is_the_public_address(project: Path, tmp_path: Path) -> None:  # noqa: F811
    httpd = serve(project, tmp_path / "state")
    url = json.loads(get(httpd, "/api/phone")[1])["url"]
    assert url.startswith("https://logos.example.org/?k=")
    key = url.split("k=")[1]
    status, _, headers = get(httpd, f"/?k={key}", PUBLIC)
    assert status == 303 and "Secure" in headers["Set-Cookie"], "over https the cookie is https-only"
