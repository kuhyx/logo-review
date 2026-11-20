"""Pairing a device that reaches the tool through a public address.

This computer hands out a short code (six digits, five minutes, one use); the device trades it for a long
key of its own. Only the key's hash is stored, in <data>/devices.json: delete that file to unpair every device.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import secrets
import threading
import time
from collections.abc import Callable
from pathlib import Path

CODE_TTL = 300.0
MAX_PENDING = 5
MAX_WRONG = 5  # six digits are guessable: this many wrong tries drop every waiting code


class PairCodes:
    """Codes waiting to be used. Kept in memory: a restart cancels them."""

    def __init__(self, clock: Callable[[], float] = time.monotonic) -> None:
        self.clock = clock
        self.pending: dict[str, float] = {}
        self.wrong = 0
        self.lock = threading.Lock()

    def mint(self) -> str:
        with self.lock:
            code = f"{secrets.randbelow(10**6):06d}"
            self.pending[code] = self.clock() + CODE_TTL
            while len(self.pending) > MAX_PENDING:
                self.pending.pop(next(iter(self.pending)))
            self.wrong = 0
            return code

    def redeem(self, offered: object) -> bool:
        with self.lock:
            now = self.clock()
            self.pending = {code: end for code, end in self.pending.items() if end > now}
            match = next((code for code in self.pending if isinstance(offered, str) and hmac.compare_digest(code, offered)), None)
            if match is None:
                self.wrong += 1
                if self.wrong >= MAX_WRONG:
                    self.pending.clear()
                return False
            del self.pending[match]
            return True


class Devices:
    """The paired devices' key hashes, re-read on every check so the file is the truth."""

    def __init__(self, file: Path) -> None:
        self.file = file
        self.lock = threading.Lock()

    def _hashes(self) -> list[str]:
        try:
            value = json.loads(self.file.read_text())
        except (OSError, ValueError):
            return []
        return [h for h in value if isinstance(h, str)] if isinstance(value, list) else []

    def add(self) -> str:
        token = secrets.token_urlsafe(32)
        with self.lock:
            hashes = [*self._hashes(), hashlib.sha256(token.encode()).hexdigest()]
            self.file.parent.mkdir(parents=True, exist_ok=True)
            tmp = self.file.with_suffix(".tmp")
            tmp.touch(mode=0o600)
            tmp.write_text(json.dumps(hashes))
            os.replace(tmp, self.file)
        return token

    def check(self, token: str) -> bool:
        offered = hashlib.sha256(token.encode()).hexdigest()
        return any(hmac.compare_digest(offered, known) for known in self._hashes())
