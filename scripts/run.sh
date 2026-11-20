#!/bin/bash
# run.sh — start (or restart) the review server for one project as a user service. Remembers the
# project, so deploy.sh can restart it later.
# Usage: scripts/run.sh <project-dir> [port] [public-url]
# Without a public url the server listens on the local network, behind a key. With one (the https address
# a reverse proxy serves it at) it stays on loopback, and phones come in through the proxy.
# LOGO_REVIEW_SERVICES_SOURCE: a file:// mirror of the service logos instead of the pinned CDN (tests).
# Needs: python3, qrencode (QR code for the phone link), systemd user session.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
readonly HERE
readonly CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/logo-review"
readonly UNIT="${LOGO_REVIEW_UNIT:-logo-review}"

main() {
	local project="${1:?usage: run.sh <project-dir> [port] [public-url]}" port="${2:-8793}" public="${3:-}"
	local -a reach=(--lan) logos=()
	[[ -z "${LOGO_REVIEW_SERVICES_SOURCE:-}" ]] || logos=(--services-source "$LOGO_REVIEW_SERVICES_SOURCE")
	[[ -z "$public" ]] || reach=(--public "$public")
	project="$(cd "$project" && pwd)"
	[[ -f "$project/rounds.json" ]] || { echo "no rounds.json in $project" >&2; exit 1; }
	command -v qrencode >/dev/null || sudo pacman -S --needed --noconfirm qrencode
	mkdir -p "$CONFIG"
	printf 'PROJECT=%q\nPORT=%q\nPUBLIC=%q\n' "$project" "$port" "$public" >"$CONFIG/env"
	systemctl --user stop "$UNIT" 2>/dev/null || true
	systemd-run --user --collect --quiet --unit="$UNIT" -p Restart=on-failure \
		python3 "$HERE/server.py" --project "$project" --port "$port" "${reach[@]}" \
		--errors "${XDG_STATE_HOME:-$HOME/.local/state}/app-errors-spool/logo-review.jsonl" "${logos[@]}"
	curl -sf -o /dev/null --retry 20 --retry-connrefused --retry-delay 0 --retry-max-time 8 "http://127.0.0.1:${port}/api/manifest"
	echo "logo-review: http://127.0.0.1:${port}/"
}

main "$@"
