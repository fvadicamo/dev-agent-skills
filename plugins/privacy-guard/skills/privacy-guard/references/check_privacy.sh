#!/usr/bin/env bash
# Privacy guard: block commits containing tokens from a local denylist.
#
# The denylist lives OUTSIDE version control (.local/privacy-denylist.txt)
# because publishing the list would defeat its purpose. When the file does
# not exist (e.g. for external contributors or CI), the check is a no-op.
#
# Denylist format: one extended-regex pattern per line, '#' starts a comment.
# Matching is case-insensitive. Override the path with PRIVACY_DENYLIST.
#
# Scans ONLY the lines a commit ADDS, never the whole file. A pre-commit guard's job
# is to stop NEW leaks; a token already sitting in a committed line is already in the
# repo, and failing on it wedges every later edit to that file. Measured: a repo whose
# docs legitimately name the tokens its own denylist protects became unmaintainable,
# and the only exit the message offered was --no-verify, which is how a guard stops
# guarding while staying installed.
#
# Scanning the diff also means scanning only '+' lines, never '-'. A guard that reads
# the whole diff would fail on the commit that REMOVES a leak, because the removed
# line is still in it. (That failure does not exist in the whole-file form this
# replaced, so it is a trap of the new shape, not a defect of the old one.)

set -euo pipefail

DENYLIST="${PRIVACY_DENYLIST:-.local/privacy-denylist.txt}"

[ -f "$DENYLIST" ] || exit 0

patterns_file=$(mktemp "${TMPDIR:-/tmp}/privacy-patterns.XXXXXX")
trap 'rm -f "$patterns_file"' EXIT
grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$DENYLIST" > "$patterns_file" || true
[ -s "$patterns_file" ] || exit 0

# Added lines of one staged file, each prefixed with its REAL line number in the new
# file. The number comes from the hunk headers: `grep -n` over a diff would number the
# lines of the diff, not of the file, and a guard whose output points at the wrong line
# sends whoever reads it to look in the wrong place.
added_lines() {
    git diff --cached -U0 -- "$1" | awk '
        /^\+\+\+/ { next }
        /^@@/     { split($3, h, ","); n = substr(h[1], 2) + 0; next }
        /^\+/     { print n ":" substr($0, 2); n++ }
    '
}

status=0
checked=0
for file in "$@"; do
    added=$(added_lines "$file")
    [ -n "$added" ] || continue
    checked=$((checked + 1))
    # -i case-insensitive, -E extended regex. Binary files never get here: git emits
    # no '+' lines for them, which is what `grep -I` used to take care of.
    if matches=$(printf '%s\n' "$added" | grep -iE -f "$patterns_file"); then
        echo "Privacy check FAILED:"
        printf '%s\n' "$matches" | sed "s|^|${file}:|" | head -10
        status=1
    fi
done

# Silence here would read as "clean", which is the one thing this script must never
# fake. No argument with staged additions means either the caller passed the list wrong
# (a common one: an unquoted variable under a shell that does not word-split it, so the
# whole list arrives as a single argument) or the script was run by hand outside a
# commit, where there is nothing staged to look at.
if [ "$#" -gt 0 ] && [ "$checked" -eq 0 ]; then
    echo "check_privacy.sh: none of the $# argument(s) has staged additions, nothing was checked." >&2
fi

if [ "$status" -ne 0 ]; then
    echo ""
    echo "Commit blocked: tokens from the local privacy denylist were found."
    echo "Remove the sensitive content (or adjust ${DENYLIST}) and retry."
fi
exit "$status"
