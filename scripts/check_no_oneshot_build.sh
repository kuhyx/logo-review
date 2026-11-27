#!/bin/bash
# check_no_oneshot_build.sh — fail when a doc or script of this repo runs a one-shot
# APK build. One flutter APK build holds a build slot for over 60 s (79 s cold on
# 2026-11-27); build in stages instead: scripts/emulator_apk.sh (emulator) or
# ~/.claude/scripts/phone_deploy.sh --stage (phone), each call well under 60 s.
# `--config-only` (phone_deploy's prep) is allowed. CI (.github/) has no cap and is not scanned.
# Usage: scripts/check_no_oneshot_build.sh [repo-dir]   (exit 0 ok | 1 found | 2 no dir)
set -euo pipefail
dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
readonly dir
# Split so this file does not match itself.
readonly PATTERN='flutter[[:space:]]+''build[[:space:]]+apk'

main() {
	[[ -d $dir ]] || { echo "no such repo dir: $dir" >&2; exit 2; }
	local -a files=()
	local f
	for f in "$dir"/*.md "$dir"/*.sh "$dir"/scripts/*.sh; do
		[[ -f $f ]] && files+=("$f")
	done
	(( ${#files[@]} )) || { echo "no docs or scripts under $dir" >&2; exit 2; }
	local hits
	hits="$(grep -HnE "$PATTERN" "${files[@]}" | grep -v -e '--config-only' || true)"
	if [[ -n $hits ]]; then
		echo "one-shot APK build (over 60 s); use scripts/emulator_apk.sh or phone_deploy.sh --stage:" >&2
		echo "${hits//"$dir/"/}" >&2
		exit 1
	fi
}

main "$@"; exit $?
