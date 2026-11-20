# logo-review

One page to judge rounds of logo candidates, on a computer or a phone.

- Approve, reject or ask for improvement per logo; write a note; draw marks (point, rectangle, circle, arrow) on the logo.
- See each logo where it will be used: avatars at real sizes, favicon, site header, og card, light and dark.
- Compare one type's variants side by side as the 20 px round avatar, pick one per type, then the winner.
- Copy a line-up, or every logo of the round, as one picture to paste into a chat.
- Each logo has its history across rounds and a discussion thread with the designer.

## Run

```
./run.sh [project-dir]                               # start it and open it in a window on this computer
scripts/run.sh <project-dir> [port] [public-url]     # only the server; default port 8793
```

`./run.sh` with no argument serves the project it served last. `./run.sh --no-open` starts the server
without a window.

This computer opens `http://127.0.0.1:8793/` with no key.

Without a public url the server listens on the local network. A phone browser on the same network scans the
QR code behind the phone button in the top bar; the code holds a key, which the phone keeps in a cookie.

With a public url (the https address a reverse proxy such as Caddy serves the tool at) the server stays on
loopback and every visitor through the proxy needs the key or a paired device. kuhy's runs at
`https://logos.kuhy.duckdns.org`.

## The phone app

`app/` is a Flutter app for Android (`com.kuhy.logo_review`, launcher name LogoJudge) with everything the
page does: the grid and its filters, verdicts, notes, marks drawn with a finger, the discussion, the
previews, the history, the line-ups with picks and the winner, suggestions with a reference picture, and
both share pictures (through the phone's share sheet).

Pair it once: press the phone button on the computer's page and type the six digits it shows into the app.
The code works once, for five minutes. The app then holds a key of its own (in the Android keystore); the
server keeps only the key's hash in `<project-dir>/devices.json`. Delete that file to unpair every device.

Signed APKs are on the Releases page, one per push. Errors in the app show at the bottom of the screen and
are filed on the computer in `~/.local/state/app-errors-spool/logo-review.jsonl`.

## A project

A project directory holds `rounds.json` (see the top of `server.py`), the archived `feedback-round<N>.json`
files, and what the page writes: `feedback.json` and `refs/`. The designer writes `answers.json`.

## Checks

```
python3 -m pytest                                              # the server, on a throwaway project
scripts/check_app.sh                                           # the phone app: analyze, tests, coverage
LOGO_REVIEW_PROJECT=<project-dir> ./run-check.sh check.mjs          # the page at desktop size
LOGO_REVIEW_PROJECT=<project-dir> ./run-check.sh check-mobile.mjs   # the page at phone size, and network access
```

The two page checks drive headless chromium and still assert details of kuhy's logo project (its round 13);
they need that project until they get a fixture of their own.
