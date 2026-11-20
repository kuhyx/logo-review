#!/bin/bash
# run-check.sh — start a throwaway review server on a scratch state dir, run one check script, stop it.
# Usage: run-check.sh [check.mjs|check-mobile.mjs] [shots-dir]
# The checks assert against a real project (its current round); point LOGO_REVIEW_PROJECT at it.
# Service logos come from a fake local mirror (tests/fake_icons.py), every service but gmail: no network.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
readonly HERE
readonly PROJECT="${LOGO_REVIEW_PROJECT:?set LOGO_REVIEW_PROJECT to a project directory (the one with rounds.json)}"
readonly CHECK="${1:-check.mjs}"
readonly SHOTS="${2:-}"
readonly PORT=18793
readonly UNIT="logo-review-check"
SCRATCH="$(mktemp -d)"
readonly SCRATCH

cleanup() {
	systemctl --user stop "$UNIT" 2>/dev/null || true
	rm -rf "${SCRATCH:?}"
}
trap cleanup EXIT

systemctl --user stop "$UNIT" 2>/dev/null || true
python3 "$HERE/tests/fake_icons.py" "$SCRATCH/cdn" --without gmail
systemd-run --user --collect --quiet --unit="$UNIT" -p RuntimeMaxSec=300 \
	python3 "$HERE/server.py" --project "$PROJECT" --data "$SCRATCH" --port "$PORT" --lan \
	--services-dir "$SCRATCH/services" --services-source "file://$SCRATCH/cdn"
curl -s -o /dev/null --retry 20 --retry-connrefused --retry-delay 0 --retry-max-time 6 "http://127.0.0.1:${PORT}/"
node "$HERE/$CHECK" "http://127.0.0.1:${PORT}" "$SCRATCH/answers.json" "$SHOTS"
