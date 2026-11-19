#!/bin/bash
# run.sh — start (or restart) the review server for one project as a user service, reachable from the
# local network behind a key. Remembers the project, so deploy.sh can restart it later.
# Usage: scripts/run.sh <project-dir> [port]
# Needs: python3, qrencode (QR code for the phone link), systemd user session.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
readonly HERE
readonly CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/logo-review"
readonly UNIT="logo-review"

main() {
	local project="${1:?usage: run.sh <project-dir> [port]}" port="${2:-8793}"
	project="$(cd "$project" && pwd)"
	[[ -f "$project/rounds.json" ]] || { echo "no rounds.json in $project" >&2; exit 1; }
	command -v qrencode >/dev/null || sudo pacman -S --needed --noconfirm qrencode
	mkdir -p "$CONFIG"
	printf 'PROJECT=%q\nPORT=%q\n' "$project" "$port" >"$CONFIG/env"
	systemctl --user stop "$UNIT" 2>/dev/null || true
	systemd-run --user --collect --quiet --unit="$UNIT" -p Restart=on-failure \
		python3 "$HERE/server.py" --project "$project" --port "$port" --lan
	curl -sf -o /dev/null --retry 20 --retry-connrefused --retry-delay 0 --retry-max-time 8 "http://127.0.0.1:${port}/api/manifest"
	echo "logo-review: http://127.0.0.1:${port}/"
}

main "$@"
