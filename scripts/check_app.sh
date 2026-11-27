#!/bin/bash
# check_app.sh — the phone app's gate: analyze clean, tests green, every logic line covered,
# no source file over 250 lines, no one-shot APK build in docs or scripts.
# Usage: scripts/check_app.sh  (BUILD_GATE_DIR=<dir> runs that gate on another copy)
# Needs: the Flutter SDK pinned in app/.fvmrc (fvm, or flutter on PATH).
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
readonly MAX_LINES=250

main() {
	# First and fast (~0 s): no doc or script may hold a build slot for a one-shot APK build.
	"$REPO_DIR/scripts/check_no_oneshot_build.sh" "${BUILD_GATE_DIR:-$REPO_DIR}"
	cd "$REPO_DIR/app"
	local long
	long="$(find lib test tool -name '*.dart' -exec awk -v max="$MAX_LINES" 'END { if (NR > max) print FILENAME ": " NR }' {} \;)"
	if [[ -n "$long" ]]; then
		echo "over ${MAX_LINES} lines:" >&2
		echo "$long" >&2
		exit 1
	fi
	flutter analyze --fatal-infos --fatal-warnings
	flutter test --coverage --concurrency="${APP_TEST_CONCURRENCY:-2}" -r failures-only
	dart run tool/check_coverage.dart
}

main "$@"
