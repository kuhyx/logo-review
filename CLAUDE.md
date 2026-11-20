## Commands

- run: `./run.sh [project-dir]` (server + desktop window; `scripts/run.sh <project-dir>` is the server alone)
- test: `python3 -m pytest && scripts/check_app.sh`
- e2e: `LOGO_REVIEW_PROJECT=<project-dir> ./run-check.sh check.mjs && LOGO_REVIEW_PROJECT=<project-dir> ./run-check.sh check-mobile.mjs`
- deploy: `~/src/logo-review/scripts/deploy.sh` (server); `~/.claude/scripts/phone_deploy.sh ~/src/logo-review/app --release --stage <step>` (phone app)

## Notes

- `index.html` is the whole page (no build step); `server.py` is stdlib only.
- The page shows no words beyond logo ids and what the reviewer or designer wrote: icons and aria-labels only.
- The server runs as a transient user unit (`logo-review`), so it does not come back after a reboot until `scripts/run.sh` runs again.
- `app/` is the Flutter phone app. `lib/` outside `lib/ui/` is held to 100 % line coverage (`tool/check_coverage.dart`); every Dart file stays at or under 250 lines. The app shows no words beyond ids and what people wrote, like the page.
- The app and the page share `feedback.json`: change a field in `index.html` and in `app/lib/models.dart` together.
- Tests of the app never touch a real project: `app/test/fakes.dart` is the server in memory. On a device, look only; a tap that writes lands in kuhy's real feedback.
- Service logos (`services.py`): brand marks never go in git (public repo); `assets/services/manifest.json` is the only committed file there. A simple-icons bump is its own change: edit `VERSION`, run `python3 services.py manifest`, delete the fetched files. Add a service in `services.py`, `index.html` (`AVATARS`) and `app/lib/ui/avatars.dart` together.
- `check.mjs` asserts round 13 of kuhy's logo project; point `LOGO_REVIEW_PROJECT` at a project whose `rounds.json` shows round 13.
- Core flows: `DOCS-features.md`.
