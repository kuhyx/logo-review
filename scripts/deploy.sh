#!/bin/bash
# deploy.sh — update the checkout this script lives in and restart the running review server from it.
# Exits non-zero unless the server answers afterwards. With no remembered project there is nothing to
# restart: that is a pass, not a failure.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
readonly HERE
readonly ENV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/logo-review/env"

main() {
	git -C "$HERE" pull --ff-only --quiet
	if [[ ! -f "$ENV_FILE" ]]; then
		echo "logo-review: updated; no project is being served"
		return 0
	fi
	# shellcheck source=/dev/null
	source "$ENV_FILE"
	"$HERE/scripts/run.sh" "$PROJECT" "$PORT" "${PUBLIC:-}"
}

main "$@"
