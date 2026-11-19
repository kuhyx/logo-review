## Commands

- run: `scripts/run.sh <project-dir>`
- test: `python3 -m pytest`
- e2e: `LOGO_REVIEW_PROJECT=<project-dir> ./run-check.sh check.mjs && LOGO_REVIEW_PROJECT=<project-dir> ./run-check.sh check-mobile.mjs`
- deploy: `~/src/logo-review/scripts/deploy.sh`

## Notes

- `index.html` is the whole page (no build step); `server.py` is stdlib only.
- The page shows no words beyond logo ids and what the reviewer or designer wrote: icons and aria-labels only.
- The server runs as a transient user unit (`logo-review`), so it does not come back after a reboot until `scripts/run.sh` runs again.
