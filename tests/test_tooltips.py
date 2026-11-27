"""Every hover tooltip on the page is one word (kuhy's textgate exception).

The page's tooltips are `title=` attributes and `.title =` assignments. A title
built from the round's own data (tool, type or column names) is the designer's
text, so only the template expressions listed in DATA_DRIVEN may appear.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

PAGE = (Path(__file__).resolve().parent.parent / "index.html").read_text()
ONE_WORD = re.compile(r"^[A-Za-z0-9-]{1,20}$")
DATA_DRIVEN = {"${t}", "${MANIFEST.types[t]}", "${a.tip}", "${tip}", "${o.tip}", '${final ? "Winner" : "Pick"}'}


def _titles() -> list[str]:
    """Return every title the page sets, as written in the source."""
    attrs = re.findall(r'title="((?:\$\{[^}]*\}|[^"])*)"', PAGE)
    props = re.findall(r"\.title = (`[^`]*`|\"[^\"]*\"|'[^']*')", PAGE)
    return attrs + [p[1:-1] for p in props]


def test_literal_titles_are_one_word() -> None:
    """Fixed titles name the icon in one word; data titles are only the known ones."""
    bad = [t for t in _titles() if t not in DATA_DRIVEN and not ONE_WORD.match(t)]
    assert bad == []


def test_avatar_and_header_tips_are_one_word() -> None:
    """The words fed into `${a.tip}` and `${tip}` follow the same rule."""
    avatars = [tip or name for name, tip in re.findall(r'\{ id: "[^"]+", chip: "[^"]+", name: "([^"]*)",(?: tip: "([^"]*)",)?', PAGE)]
    tips = avatars + re.findall(r'header\("[^"]+", \d+, "([^"]*)"\)', PAGE)
    assert len(tips) >= 9
    assert [t for t in tips if not ONE_WORD.match(t)] == []


def test_corner_mark_tips_are_one_word() -> None:
    """The words fed into `${o.tip}`: each corner mark's tooltip in the #overlays table."""
    table = json.loads(re.search(r'<script type="application/json" id="overlays">(.*?)</script>', PAGE, re.S).group(1))
    assert sorted({m["tip"] for m in table.values()}) == ["Edit", "Online"]
