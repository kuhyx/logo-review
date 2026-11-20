#!/bin/bash
# set_release_secrets.sh — set the four GitHub secrets .github/workflows/app.yml needs to sign the
# APK, from app/android/key.properties (gitignored; a copy of the shared ~/.android/release one).
# Values go to `gh secret set` on stdin, never on the command line.
# Usage: scripts/set_release_secrets.sh [--dry-run]   (--dry-run prints names and lengths only)
# Needs: gh (logged in), base64.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
readonly GH_REPO="kuhyx/logo-review"
readonly PROPS="$REPO_DIR/app/android/key.properties"
DRY_RUN=0

die() {
	printf 'error: %s\n' "$1" >&2
	exit 1
}

prop() { grep -E "^$1=" "$PROPS" | cut -d= -f2-; }

# put NAME VALUE: sets one secret, or reports its length on --dry-run.
put() {
	[[ -n "$2" ]] || die "$1 would be empty; refusing"
	if [[ "$DRY_RUN" == 1 ]]; then
		printf '   %-26s %s chars\n' "$1" "${#2}"
	else
		printf '%s' "$2" | gh secret set "$1" -R "$GH_REPO"
	fi
}

main() {
	[[ "${1:-}" != "--dry-run" ]] || DRY_RUN=1
	[[ -f "$PROPS" ]] || die "no $PROPS"
	local store
	store="$(prop storeFile)"
	[[ -f "$store" ]] || die "keystore $store not found"
	put ANDROID_KEYSTORE_BASE64 "$(base64 -w0 "$store")"
	put ANDROID_KEYSTORE_PASSWORD "$(prop storePassword)"
	put ANDROID_KEY_ALIAS "$(prop keyAlias)"
	put ANDROID_KEY_PASSWORD "$(prop keyPassword)"
}

main "$@"
