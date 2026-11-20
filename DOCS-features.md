# Features

What the tool does, and the five flows that must keep working. Each flow names the check that proves it.

## Core flows

| # | Flow | Check |
|---|---|---|
| 1 | Pair a phone: type the computer's six digits into the app, see the round's logos | `app/test/app_flow_test.dart`; server side `tests/test_pairing.py` |
| 2 | Review a logo: verdict, note, marks drawn on it, a question in the discussion; all saved to `feedback.json` | `app/test/screens_test.dart` ("review: ..."); page: `check.mjs` |
| 3 | Compare one type's variants as the 20 px avatar, pick one per type, then the winner | `app/test/flows_test.dart` ("compare: ..."); page: `check.mjs` |
| 4 | Share a line-up, or every logo, as one picture | `app/test/flows_test.dart` ("share every logo ..."); page: `check-mobile.mjs` |
| 5 | Suggest a new direction with a link and a reference picture | `app/test/flows_test.dart` ("ideas: ..."); server: `tests/test_server.py` |

Service logos: each avatar place (14 services) wears the service's real mark as its frame badge, white on the dark
preview, its chip when the server has no logo yet. `services.py` fetches them at server start from simple-icons
(pinned version, one CDN host) into the gitignored `assets/services/`; `/services/<id>.svg|png` serves the 14 ids only.
Checks: `tests/test_services.py`, `check.mjs` (fake local mirror, no network), `app/test/badge_test.dart`.

Phone layout (nothing scrolls on a main screen, the keyboard covers nothing): `app/test/layout_test.dart`.

## Access

| Who | How | Check |
|---|---|---|
| This computer | loopback peer and loopback Host: no key | `tests/test_server.py` |
| A phone browser | `/?k=<key>` once (QR code), then a cookie | `tests/test_server.py`, `check-mobile.mjs` |
| The phone app | six-digit code once, then `Authorization: Bearer <device key>` | `tests/test_pairing.py` |
| Anyone else | 403 | `tests/test_pairing.py` |

## Not in the app

The QR code and the pairing code are only handed out on the computer's page. The desktop keeps using the
page; the app is built for Android only.
