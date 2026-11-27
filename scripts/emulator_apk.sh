#!/bin/bash
# emulator_apk.sh — the app's debug APK for this session's emulator, pointed at a test
# server on this computer (10.0.2.2:<port> is the host from inside the emulator).
# One stage per call, each well under the 60 s cap (a one-shot build took 79 s cold):
#   scripts/emulator_apk.sh prep <port>
#   scripts/emulator_apk.sh dart | kotlin | assemble | install   (kernel / aot split dart further)
# Each call prints `<stage>: wait <n> s, build <n> s` (wait = queued for the build lock).
# Never the phone: the serial is the emulator's (emulator_run.sh serial) unless ADB_SERIAL
# names another emulator. PHONE_DEPLOY overrides the phone_deploy.sh path (tests, worktrees).
# Exit codes: phone_deploy.sh's, or 2 usage (prep needs a port; ADB_SERIAL not an emulator).
set -euo pipefail
shopt -s lastpipe
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
readonly PHONE_DEPLOY="${PHONE_DEPLOY:-$HOME/.claude/scripts/phone_deploy.sh}"
readonly STAGES="prep kernel aot dart kotlin assemble install"

usage() { echo "usage: emulator_apk.sh <${STAGES// /|}> [port] (prep needs the port)" >&2; exit 2; }

main() {
	local stage="${1:-}" port="${2:-}" serial
	[[ " $STAGES " == *" $stage "* ]] || usage
	[[ -z $port || $port =~ ^[0-9]+$ ]] || usage
	[[ $stage != prep || -n $port ]] || usage
	serial="${ADB_SERIAL:-$("$HOME/.claude/scripts/emulator_run.sh" serial)}"
	[[ $serial == emulator-* ]] || { echo "not an emulator: $serial" >&2; exit 2; }
	local -a defines=()
	[[ -z $port ]] || defines=(--dart-define "LOGO_REVIEW_URL=http://10.0.2.2:$port")
	local started=$SECONDS waited=0 line rc
	set +e  # a failed stage still prints its seconds, then exits with phone_deploy's code
	ADB_SERIAL="$serial" "$PHONE_DEPLOY" "$REPO_DIR/app" --stage "$stage" "${defines[@]}" 2>&1 \
		| while IFS= read -r line; do
			printf '%s\n' "$line"
			if [[ $line =~ ^build\ lock\ taken\ after\ ([0-9]+)\ s ]]; then waited=${BASH_REMATCH[1]}; fi
		done
	rc=${PIPESTATUS[0]}
	set -e
	printf '%s: wait %d s, build %d s\n' "$stage" "$waited" "$((SECONDS - started - waited))"
	return "$rc"
}

main "$@"; exit $?
