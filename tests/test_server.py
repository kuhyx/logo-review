"""The review server against a throwaway project: rounds from rounds.json, kuhy's state, and LAN access."""

from __future__ import annotations

import http.client
import json
import threading
from http.server import ThreadingHTTPServer
from pathlib import Path

import pytest

import server

PNG = bytes.fromhex("89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d49444154789c6360606060000000050001a5f645400000000049454e44ae426082")


@pytest.fixture
def project(tmp_path: Path) -> Path:
    for folder, name in (("r2/out/css", "A1-c"), ("r1/out/svg", "A1-c"), ("r0", "a1/512")):
        file = tmp_path / folder / f"{name}.png"
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_bytes(PNG)
    (tmp_path / "r2/out/manifest.json").write_text(json.dumps({"round": 2, "tools": ["css"], "ids": ["A1"], "names": {"A1": "a"}}))
    (tmp_path / "r2/out/history.json").write_text(json.dumps({"A1": [{"round": 1, "id": "A1", "text": "before"}]}))
    (tmp_path / "rounds.json").write_text(json.dumps({
        "current": "r2/out",
        "old": {"0": {"dir": "r0", "file": "{name}/512.png", "tools": []}, "1": {"dir": "r1/out/svg", "tools": ["svg", "css"]}},
    }))
    (tmp_path / "feedback-round1.json").write_text(json.dumps({"logos": {"css/A1-c": {"note": "too thin"}}}))
    return tmp_path


def serve(project: Path, data: Path, lan: bool, peer: str | None = None):
    handler = server.make_handler(server.Project(project), data, lan=lan, lan_url="http://192.168.1.43:1/")
    if peer:  # pretend every request comes from this address
        handler.peer = lambda self: peer
    httpd = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def get(httpd, path: str, headers: dict | None = None):
    conn = http.client.HTTPConnection("127.0.0.1", httpd.server_address[1], timeout=5)
    conn.request("GET", path, headers=headers or {})
    res = conn.getresponse()
    return res.status, res.read(), dict(res.getheaders())


def test_rounds_come_from_the_project_file(project: Path, tmp_path: Path) -> None:
    httpd = serve(project, tmp_path / "state", lan=False)
    assert json.loads(get(httpd, "/api/manifest")[1])["round"] == 2
    assert get(httpd, "/img/css/A1-c.png")[1] == PNG
    assert get(httpd, "/img/rough/A1-c.png")[0] == 404, "a tool the manifest does not list is not served"
    assert get(httpd, "/old/1/A1-c.png")[1] == PNG
    assert get(httpd, "/old/0/a1.png")[1] == PNG, "a round may keep its pictures under another file pattern"
    assert get(httpd, "/old/7/A1-c.png")[0] == 404
    history = json.loads(get(httpd, "/api/history")[1])
    assert history["said"]["1"]["css/A1-c"]["note"] == "too thin" and history["tools"]["1"] == ["svg", "css"]
    assert history["steps"]["A1"][0]["text"] == "before"
    assert get(httpd, "/old/1/..%2f..%2frounds.json")[0] == 404


def test_state_lives_in_the_data_dir(project: Path, tmp_path: Path) -> None:
    httpd = serve(project, tmp_path / "state", lan=False)
    conn = http.client.HTTPConnection("127.0.0.1", httpd.server_address[1], timeout=5)
    conn.request("PUT", "/api/state", body=json.dumps({"logos": {"css/A1-c": {"verdict": "approve"}}, "ideas": []}))
    assert conn.getresponse().status == 200
    assert json.loads((tmp_path / "state/feedback.json").read_text())["logos"]["css/A1-c"]["verdict"] == "approve"
    assert not (project / "feedback.json").exists()


def test_this_computer_needs_no_key_and_gets_the_phone_link(project: Path, tmp_path: Path) -> None:
    httpd = serve(project, tmp_path / "state", lan=True)
    assert get(httpd, "/")[0] == 200
    phone = json.loads(get(httpd, "/api/phone")[1])
    token = (tmp_path / "state/lan-token").read_text().strip()
    assert len(token) >= 32 and phone["url"] == f"http://192.168.1.43:1/?k={token}"
    status, body, headers = get(httpd, "/phone.svg")
    assert status == 200 and b"<svg" in body and headers["Content-Type"].startswith("image/svg+xml")


def test_without_lan_there_is_no_phone_link(project: Path, tmp_path: Path) -> None:
    httpd = serve(project, tmp_path / "state", lan=False)
    assert json.loads(get(httpd, "/api/phone")[1]) == {"url": None}
    assert get(httpd, "/phone.svg")[0] == 404


def test_another_device_needs_the_key(project: Path, tmp_path: Path) -> None:
    serve(project, tmp_path / "state", lan=True)  # makes the token
    token = (tmp_path / "state/lan-token").read_text().strip()
    httpd = serve(project, tmp_path / "state", lan=True, peer="192.168.1.77")
    for path in ("/", "/api/state", "/img/css/A1-c.png", "/?k=wrong"):
        assert get(httpd, path)[0] == 403, path
    status, _, headers = get(httpd, f"/?k={token}")
    assert status == 303 and headers["Location"] == "/", "the key leaves the address bar after the first visit"
    cookie = headers["Set-Cookie"].split(";")[0]
    assert "HttpOnly" in headers["Set-Cookie"] and "SameSite=Strict" in headers["Set-Cookie"]
    assert get(httpd, "/", {"Cookie": cookie})[0] == 200
    assert get(httpd, "/api/state", {"Cookie": cookie})[0] == 200
    assert get(httpd, "/api/phone", {"Cookie": cookie})[0] == 403, "only this computer hands out the phone link"
    assert get(httpd, "/phone.svg", {"Cookie": cookie})[0] == 403
