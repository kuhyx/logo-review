"""Server for the logo review tool: one page to judge rounds of logo candidates, from a computer or a phone.

A *project* directory describes the rounds (rounds.json, read-only here):

  {"current": "round13/out",                      the round on show: manifest.json, rationale.json,
                                                   history.json and <tool>/<id>-c.png
   "old": {"12": {"dir": "round12/out/svg",       where an earlier round's pictures live
                  "tools": ["css", "rough"],      the tools that round was reviewed in
                  "file": "{name}.png"}}}         optional file pattern inside "dir"

Next to it sit feedback-round<N>.json: the reviewer's archived feedback per finished round.
The *data* directory (default: the project) holds what the page writes: feedback.json, refs/, and what the
designer writes between turns: answers.json. Neither side overwrites the other.

  GET  /                        the page
  GET  /img/<tool>/<name>.png   a logo of the round on show
  GET  /old/<round>/<name>.png  a logo from an earlier round
  GET  /api/manifest            the round's tools and design ids
  GET  /api/state               the reviewer's saved feedback
  PUT  /api/state               replace it (JSON object, <= 2 MB)
  GET  /api/history             each design's earlier rounds + the archived reviews
  GET  /api/claude              {"rationale": ..., "answers": ...}
  POST /api/ref                 upload a reference picture (image/*, <= 5 MB) -> {"file": name}
  GET  /ref/<name>              an uploaded reference picture
  GET  /api/phone               this computer only: {"url": the link that opens the tool on a phone, or null}
  GET  /phone.svg               this computer only: that link as a QR code

With --lan the server listens on every interface. This computer's own browser (loopback peer and a
loopback Host header with this port) needs no key; a request a reverse proxy forwards does. Any other device must open
/?k=<key> once (the QR code holds it); the key then lives in a cookie. The key is in <data>/lan-token.

Run: python3 server.py --project <dir> [--data <dir>] [--port 8793] [--lan]
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import ipaddress
import json
import os
import re
import secrets
import socket
import subprocess
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

HERE = Path(__file__).resolve().parent
MAX_STATE = 2 * 1024 * 1024
MAX_REF = 5 * 1024 * 1024
IMG_RE = re.compile(r"^/img/([a-z]+)/([A-Z][1-9]-[mc])\.png$")
OLD_RE = re.compile(r"^/old/(\d{1,2})/([A-Za-z][0-9](?:-[mc])?)\.png$")
REF_RE = re.compile(r"^/ref/([0-9a-f]{16}\.(png|jpeg|webp|gif))$")
REF_TYPES = {"image/png": "png", "image/jpeg": "jpeg", "image/webp": "webp", "image/gif": "gif"}
COOKIE = "k"


def read_json(path: Path, default: object) -> object:
    """The file's JSON, or `default` when it is missing or half-written."""
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default


class Project:
    """The rounds of one review project, read from <root>/rounds.json on every use (it changes between rounds)."""

    def __init__(self, root: Path) -> None:
        self.root = root.resolve()

    def _config(self) -> dict:
        config = read_json(self.root / "rounds.json", {})
        return config if isinstance(config, dict) else {}

    @property
    def images(self) -> Path:
        """The directory of the round on show."""
        return (self.root / str(self._config().get("current", "."))).resolve()

    @property
    def old(self) -> dict[str, dict]:
        return self._config().get("old", {})

    def old_image(self, rnd: str, name: str) -> Path | None:
        """The picture of design `name` in earlier round `rnd`, if that round is known."""
        entry = self.old.get(rnd)
        return None if entry is None else self.root / entry["dir"] / entry.get("file", "{name}.png").format(name=name)

    def said(self) -> dict[str, dict]:
        """What the reviewer said in each archived round: round -> logo key -> entry."""
        return {rnd: read_json(self.root / f"feedback-round{rnd}.json", {"logos": {}}).get("logos", {}) for rnd in self.old}


def lan_token(data: Path) -> str:
    """The key other devices need; made once and kept private to this user."""
    file = data / "lan-token"
    if not file.exists():
        data.mkdir(parents=True, exist_ok=True)
        file.touch(mode=0o600)
        file.write_text(secrets.token_urlsafe(32))
    return file.read_text().strip()


def lan_address() -> str | None:
    """This computer's address on the local network (the one its default route uses)."""
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(("192.0.2.1", 9))  # no packet is sent; this only picks the outgoing interface
        return probe.getsockname()[0]
    except OSError:
        return None
    finally:
        probe.close()


def make_handler(project: Project, data: Path, *, lan: bool = False, lan_url: str | None = None) -> type[BaseHTTPRequestHandler]:
    state = data / "feedback.json"
    refs = data / "refs"
    token = lan_token(data) if lan else ""
    phone_url = f"{lan_url}?k={token}" if lan and lan_url else None

    class Handler(BaseHTTPRequestHandler):
        def peer(self) -> str:
            return self.client_address[0]

        def _local(self) -> bool:
            """This computer's own browser: a loopback peer AND a loopback Host with this server's port.

            The peer alone is not enough: a reverse proxy on this computer connects from 127.0.0.1 for every
            visitor, and forwarding headers are written by whoever sends the request. The proxy passes the
            visitor's Host through, so that is the signal; it also stops DNS rebinding.
            """
            if not ipaddress.ip_address(self.peer().removeprefix("::ffff:")).is_loopback:
                return False
            hosts = self.headers.get_all("Host") or []
            port = self.server.server_address[1]
            return len(hosts) == 1 and hosts[0].strip().lower() in {f"127.0.0.1:{port}", f"localhost:{port}", f"[::1]:{port}"}

        def _send(self, code: int, body: bytes = b"", kind: str = "text/plain", extra: dict[str, str] | None = None) -> None:
            self.send_response(code)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            for name, value in (extra or {}).items():
                self.send_header(name, value)
            self.end_headers()
            self.wfile.write(body)

        def _json(self, value: object) -> None:
            self._send(200, json.dumps(value, ensure_ascii=False).encode(), "application/json")

        def _body(self, limit: int) -> bytes | None:
            length = int(self.headers.get("Content-Length") or 0)
            return self.rfile.read(length) if 0 < length <= limit else None

        def _allowed(self) -> bool:
            """This computer always; another device only with the key (in the link once, then in its cookie)."""
            if self._local():
                return True
            if not token:
                self._send(403)
                return False
            url = urlsplit(self.path)
            offered = parse_qs(url.query).get(COOKIE, [""])[0]
            if offered and hmac.compare_digest(offered, token) and url.path == "/":
                # Keep the key out of the address bar and the history: set the cookie, then show the plain page.
                self._send(303, extra={"Location": "/", "Set-Cookie": f"{COOKIE}={token}; Path=/; HttpOnly; SameSite=Strict; Max-Age=31536000"})
                return False
            cookie = SimpleCookie(self.headers.get("Cookie", "")).get(COOKIE)
            if cookie is not None and hmac.compare_digest(cookie.value, token):
                return True
            self._send(403)
            return False

        def do_GET(self) -> None:  # noqa: N802 (http.server API)
            if not self._allowed():
                return
            path = urlsplit(self.path).path
            images = project.images
            if path == "/":
                self._send(200, (HERE / "index.html").read_bytes(), "text/html; charset=utf-8")
            elif path == "/api/state":
                self._json(read_json(state, {"logos": {}, "ideas": []}))
            elif path == "/api/manifest":
                self._json(read_json(images / "manifest.json", {"round": 0, "tools": [], "ids": [], "names": {}}))
            elif path == "/api/claude":
                self._json({"rationale": read_json(images / "rationale.json", {"designs": {}, "tools": {}}), "answers": read_json(data / "answers.json", {})})
            elif path == "/api/phone":
                self._json({"url": phone_url}) if self._local() else self._send(403)
            elif path == "/phone.svg":
                if not self._local():
                    self._send(403)
                elif phone_url is None:
                    self._send(404)
                else:
                    code = subprocess.run(["qrencode", "-t", "SVG", "-m", "2", "-o", "-", phone_url], capture_output=True, check=False, timeout=10)
                    self._send(200, code.stdout, "image/svg+xml") if code.returncode == 0 else self._send(500)
            elif match := IMG_RE.match(path):
                # Only tools the manifest lists: a rejected round's renders are not served.
                tools = read_json(images / "manifest.json", {}).get("tools", [])
                file = images / (match[1] if match[1] in tools else "-") / f"{match[2]}.png"
                self._send(200, file.read_bytes(), "image/png") if file.exists() else self._send(404)
            elif path == "/api/history":
                # The design's earlier rounds, with what the reviewer said in each archived review.
                tools = {rnd: entry.get("tools", []) for rnd, entry in project.old.items()}
                self._json({"steps": read_json(images / "history.json", {}), "said": project.said(), "tools": tools})
            elif match := OLD_RE.match(path):
                file = project.old_image(match[1], match[2])
                self._send(200, file.read_bytes(), "image/png") if file and file.exists() else self._send(404)
            elif match := REF_RE.match(path):
                file = refs / match[1]
                self._send(200, file.read_bytes(), f"image/{match[2]}") if file.exists() else self._send(404)
            else:
                self._send(404)

        def do_PUT(self) -> None:  # noqa: N802
            if not self._allowed():
                return
            body = self._body(MAX_STATE) if self.path == "/api/state" else None
            try:
                value = json.loads(body) if body else None
            except ValueError:
                value = None
            if not isinstance(value, dict) or not isinstance(value.get("logos"), dict):
                self._send(400)
                return
            # Write beside the target, then rename: a killed server never leaves half a file.
            data.mkdir(parents=True, exist_ok=True)
            tmp = state.with_suffix(".tmp")
            tmp.write_text(json.dumps(value, indent=1, ensure_ascii=False))
            os.replace(tmp, state)
            self._json({})

        def do_POST(self) -> None:  # noqa: N802
            if not self._allowed():
                return
            ext = REF_TYPES.get(self.headers.get("Content-Type", ""))
            body = self._body(MAX_REF) if self.path == "/api/ref" and ext else None
            if body is None:
                self._send(400)
                return
            refs.mkdir(parents=True, exist_ok=True)
            name = f"{hashlib.sha256(body).hexdigest()[:16]}.{ext}"
            (refs / name).write_bytes(body)
            self._json({"file": name})

        def log_message(self, *_args: object) -> None:
            """Stay quiet: the journal is not a request log."""

    return Handler


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--project", type=Path, required=True, help="directory with rounds.json and the archived feedback")
    parser.add_argument("--data", type=Path, help="where feedback.json, answers.json and refs/ live (default: the project)")
    parser.add_argument("--port", type=int, default=8793)
    parser.add_argument("--lan", action="store_true", help="also serve other devices on the network, behind a key")
    args = parser.parse_args()
    address = lan_address() if args.lan else None
    lan_url = f"http://{address}:{args.port}/" if address else None
    handler = make_handler(Project(args.project), (args.data or args.project).resolve(), lan=args.lan, lan_url=lan_url)
    ThreadingHTTPServer(("0.0.0.0" if args.lan else "127.0.0.1", args.port), handler).serve_forever()


if __name__ == "__main__":
    main()
