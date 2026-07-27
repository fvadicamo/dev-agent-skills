#!/usr/bin/env bash
# Privacy guard: block commits containing tokens from a local denylist.
#
# The denylist lives OUTSIDE version control (.local/privacy-denylist.txt)
# because publishing the list would defeat its purpose. When the file does
# not exist (e.g. for external contributors or CI), the check is a no-op.
#
# Denylist format: one extended-regex pattern per line, '#' starts a comment.
# Matching is case-insensitive. Override the path with PRIVACY_DENYLIST.

set -euo pipefail

DENYLIST="${PRIVACY_DENYLIST:-.local/privacy-denylist.txt}"

[ -f "$DENYLIST" ] || exit 0

patterns_file=$(mktemp "${TMPDIR:-/tmp}/privacy-patterns.XXXXXX")
trap 'rm -f "$patterns_file"' EXIT
grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$DENYLIST" > "$patterns_file" || true
[ -s "$patterns_file" ] || exit 0

status=0
for file in "$@"; do
    [ -f "$file" ] || continue
    # grep -I skips binary files; -i case-insensitive; -E extended regex
    if matches=$(grep -nHiE -I -f "$patterns_file" -- "$file"); then
        echo "Privacy check FAILED:"
        printf "%s\n" "$matches" | head -10
        status=1
    fi
done

if [ "$status" -ne 0 ]; then
    echo ""
    echo "Commit blocked: tokens from the local privacy denylist were found."
    echo "Remove the sensitive content (or adjust ${DENYLIST}) and retry."
fi
exit "$status"
