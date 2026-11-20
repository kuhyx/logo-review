#!/bin/bash
# run.sh — start the review tool on this computer and open it in a window.
# Usage: ./run.sh [project-dir] [--no-open]
# With no project-dir it serves the project it served last (remembered by scripts/run.sh in
# ~/.config/logo-review/env, with its port and public address). --no-open only starts the server.
# LOGO_REVIEW_PORT overrides the port. Needs: python3, qrencode, a systemd user session; chromium
# (or any browser behind xdg-open) for the window.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
readonly HERE
readonly ENV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/logo-review/env"

open_window() {
	local url="$1" browser
	for browser in chromium google-chrome-stable; do
		if command -v "$browser" >/dev/null; then
			# An app window: no tabs, no address bar. Detached, so closing the terminal keeps it.
			setsid -f "$browser" --app="$url" --class=logo-review >/dev/null 2>&1
			return 0
		fi
	done
	xdg-open "$url" >/dev/null 2>&1
}

main() {
	local project="" open=1 arg
	for arg in "$@"; do
		case "$arg" in
		--no-open) open=0 ;;
		-h | --help)
			sed -n '2,7s/^# \{0,1\}//p' "$0"
			return 0
			;;
		*) project="$arg" ;;
		esac
	done
	local PROJECT="" PORT="" PUBLIC=""
	# shellcheck source=/dev/null
	[[ ! -f "$ENV_FILE" ]] || source "$ENV_FILE"
	project="${project:-$PROJECT}"
	if [[ -z "$project" ]]; then
		echo "run.sh: no project remembered yet; give one: ./run.sh <project-dir> (the directory with rounds.json)" >&2
		return 1
	fi
	local port="${LOGO_REVIEW_PORT:-${PORT:-8793}}"
	"$HERE/scripts/run.sh" "$project" "$port" "$PUBLIC"
	[[ "$open" == 0 ]] || open_window "http://127.0.0.1:${port}/"
}

main "$@"
