#!/usr/bin/env bash
# Regression tests for the privacy-guard scripts.
# Run after ANY change to references/check_privacy.sh or references/check-sync.sh.
#
#   bash tests/run.sh
#
# Overrides (for development):
#   PRIVACY_SCRIPT=/path/to/candidate.sh   test a candidate instead of the shipped one
#   SYNC_SCRIPT=/path/to/candidate.sh      same, for check-sync.sh
#
# Every case is named after the defect it holds down, so a regression is recognised by name
# rather than by line number. All of them were met in the field, not imagined.
#
# One case is marked XFAIL: it asserts behaviour the script does NOT have yet, and it is
# reported without failing the run. That is deliberate. Deleting it would lose the only
# executable record of an open defect; letting it fail would leave a permanently red suite,
# which is a suite people stop reading. When the defect is fixed the runner says so and
# tells you to drop the marker.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REF="$here/../skills/privacy-guard/references"
CHECK="${PRIVACY_SCRIPT:-$REF/check_privacy.sh}"
SYNC="${SYNC_SCRIPT:-$REF/check-sync.sh}"
[ -f "$CHECK" ] || { echo "missing: $CHECK" >&2; exit 2; }
[ -f "$SYNC" ]  || { echo "missing: $SYNC" >&2; exit 2; }

TOKEN='SYNTHETIC-DENYLISTED-TOKEN'
pass=0; fail=0; xfail=0; xpass=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

repo() {  # $1 name, $2 denylist body ('-' for none) -> path, with one committed file
    d="$T/$1"; mkdir -p "$d/.local"; git init -q "$d"
    git -C "$d" config user.email t@example.com; git -C "$d" config user.name t
    [ "$2" = "-" ] || printf '%s\n' "$2" > "$d/.local/privacy-denylist.txt"
    printf 'first line\n' > "$d/doc.md"
    git -C "$d" add -A >/dev/null 2>&1; git -C "$d" commit -qm base
    echo "$d"
}

ok() {  # $1 expected, $2 got, $3 name
    if [ "$1" = "$2" ]; then printf '  ok    %-6s %s\n' "$2" "$3"; pass=$((pass+1))
    else printf '  FAIL  expected=%s got=%s  %s\n' "$1" "$2" "$3"; fail=$((fail+1)); fi
}

xok() {  # like ok(), but a mismatch is EXPECTED and does not fail the run
    if [ "$1" = "$2" ]; then
        printf '  XPASS %-6s %s\n' "$2" "$3"
        printf '        the defect this case records is FIXED: drop the XFAIL marker.\n'
        xpass=$((xpass+1))
    else printf '  xfail expected=%s got=%s  %s\n' "$1" "$2" "$3"; xfail=$((xfail+1)); fi
}

run() { ( cd "$1" && shift && bash "$CHECK" "$@" >/dev/null 2>&1 ); echo $?; }

echo "== check_privacy.sh: what a commit ADDS, not what the file contains =="
d=$(repo added "$TOKEN")
printf 'first line\nline with %s inside\n' "$TOKEN" > "$d/doc.md"; git -C "$d" add doc.md
ok 1 "$(run "$d" doc.md)" 'a newly added token is blocked'

d=$(repo kept "$TOKEN")
printf 'first line\n%s was already committed\n' "$TOKEN" > "$d/doc.md"
git -C "$d" add -A; git -C "$d" commit -qm "token committed"
printf 'first line\n%s was already committed\nan unrelated new line\n' "$TOKEN" > "$d/doc.md"
git -C "$d" add doc.md
ok 0 "$(run "$d" doc.md)" 'an unrelated addition to a file that already holds the token passes'

printf 'first line\n' > "$d/doc.md"; git -C "$d" add doc.md
ok 0 "$(run "$d" doc.md)" 'removing the token passes'

echo "== and the reported line number is the one in the FILE, not in the diff =="
d=$(repo lineno "$TOKEN")
printf 'a\nb\nc\nd with %s\n' "$TOKEN" > "$d/doc.md"; git -C "$d" add doc.md
got=$( (cd "$d" && bash "$CHECK" doc.md 2>&1) | sed -n 's/^doc\.md:\([0-9]*\):.*/\1/p' | head -1)
ok 4 "${got:-none}" 'the match points at line 4, where the token really is'

echo "== usage errors are not a clean verdict over zero files =="
d=$(repo usage "$TOKEN")
ok 2 "$(run "$d")" 'no arguments exits 2, not 0 in silence'
d=$(repo usage-nodeny -)
ok 2 "$(run "$d")" 'no arguments exits 2 even without a denylist (usage precedes the no-op)'

echo "== and a guard with nothing to enforce says so instead of pretending =="
d=$(repo nodeny -)
printf 'first line\nline with %s inside\n' "$TOKEN" > "$d/doc.md"; git -C "$d" add doc.md
ok 0 "$(run "$d" doc.md)" 'no denylist: no-op'
d=$(repo comments '# only a comment')
printf 'first line\nline with %s inside\n' "$TOKEN" > "$d/doc.md"; git -C "$d" add doc.md
ok 0 "$(run "$d" doc.md)" 'a denylist of comments only: no-op, not a block'
d=$(repo nostaged "$TOKEN")
got=$( (cd "$d" && bash "$CHECK" doc.md 2>&1 >/dev/null) | grep -c 'nothing was checked')
ok 1 "$got" 'a file with no staged additions is reported, not passed over in silence'

echo "== XFAIL: a malformed denylist still lets a real leak through (open defect) =="
d=$(repo malformed "$TOKEN
(unclosed parenthesis")
printf 'first line\nline with %s inside\n' "$TOKEN" > "$d/doc.md"; git -C "$d" add doc.md
xok 1 "$(run "$d" doc.md)" 'grep exits 2 on a bad regex and the leak passes with exit 0'

echo "== check-sync.sh: a copy that is behind must not look current =="
csync() { ( bash "$SYNC" "$@" >/dev/null 2>&1 ); echo $?; }
d=$(repo sync-ok -); mkdir -p "$d/scripts"; cp "$REF/check_privacy.sh" "$d/scripts/"
git -C "$d" add -A; git -C "$d" commit -qm copy
ok 0 "$(csync "$d")" 'a copy identical to the canonical one is current'
sed -i.bak 's/^# check_privacy\.sh [0-9.]*/# check_privacy.sh 0.0.1/' "$d/scripts/check_privacy.sh"
rm -f "$d/scripts/check_privacy.sh.bak"; git -C "$d" add -A; git -C "$d" commit -qm older
ok 1 "$(csync "$d")" 'an older version is reported as behind'
cp "$REF/check_privacy.sh" "$d/scripts/"; printf '# local edit\n' >> "$d/scripts/check_privacy.sh"
git -C "$d" add -A; git -C "$d" commit -qm diverged
ok 1 "$(csync "$d")" 'same version with different content is reported as diverged'
d=$(repo sync-none -)
ok 0 "$(csync "$d")" 'a repo shipping no copy is reported, and is not a divergence'
ok 2 "$(csync)" 'no arguments exits 2'

printf '\n-- %d passed, %d failed, %d xfail, %d xpass --\n' "$pass" "$fail" "$xfail" "$xpass"
[ "$xpass" -gt 0 ] && echo "   an XFAIL case now passes: fix the marker before committing."
exit $(( fail > 0 || xpass > 0 ))
