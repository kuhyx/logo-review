# logo-review

One page to judge rounds of logo candidates, on a computer or a phone.

- Approve, reject or ask for improvement per logo; write a note; draw marks (point, rectangle, circle, arrow) on the logo.
- See each logo where it will be used: avatars at real sizes, favicon, site header, og card, light and dark.
- Compare one type's variants side by side as the 20 px round avatar, pick one per type, then the winner.
- Copy a line-up, or every logo of the round, as one picture to paste into a chat.
- Each logo has its history across rounds and a discussion thread with the designer.

## Run

```
scripts/run.sh <project-dir> [port]     # default port 8793
```

This computer opens `http://127.0.0.1:8793/` with no key. For a phone on the same network, press the phone
button in the top bar and scan the QR code: it holds a key, which the phone then keeps in a cookie. Without
the key every other device gets 403. The key is in `<project-dir>/lan-token`.

A phone on plain http has no clipboard for pictures, so there the copy button shows the finished picture to
press and hold.

## A project

A project directory holds `rounds.json` (see the top of `server.py`), the archived `feedback-round<N>.json`
files, and what the page writes: `feedback.json` and `refs/`. The designer writes `answers.json`.

## Checks

```
python3 -m pytest                                              # the server, on a throwaway project
LOGO_REVIEW_PROJECT=<project-dir> ./run-check.sh check.mjs          # the page at desktop size
LOGO_REVIEW_PROJECT=<project-dir> ./run-check.sh check-mobile.mjs   # the page at phone size, and network access
```

The two page checks drive headless chromium and still assert details of kuhy's logo project (its round 13);
they need that project until they get a fixture of their own.
