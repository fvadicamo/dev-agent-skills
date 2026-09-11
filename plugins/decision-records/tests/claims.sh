#!/usr/bin/env bash
# Bench of PREDICATES over the claims this plugin's documentation makes.
#
#   bash plugins/decision-records/tests/claims.sh
#
# Why this exists, and why it is not another review. A chain of re-readings has no natural
# end: every correction creates new surface, and by the sixth round most findings were about
# the previous round's corrections. What closes a chain like that is not one more reading but
# a bench: one predicate per verifiable claim, each with its own counter-proof. A green bench
# says WHAT was checked and HOW; "another reading found nothing" says neither, and does not
# distinguish a clean run from a lazy one.
#
# The class it kills is the one that actually bit, four times in one session: a number in the
# documentation that was true when written and silently stopped being true. 43 vs 51 green
# cases, "three reviews" over a five-row table, a mutation table saying three where the table
# had fourteen, and a case count that went 96 -> 99 -> 109 -> 118 while a paragraph two lines
# up kept the old one.
#
# NOT run from the pre-commit: it runs the suite twice and takes about half a minute. This is
# the check you run to CLOSE, before a release, not on every commit. `tests/run.sh` is the one
# that guards every commit.
#
# Every predicate ends with its counter-proof: the same predicate is re-run against a copy of
# the tree with one number perturbed, and it must go red there. A predicate nobody has seen
# fail is a predicate that has not been shown to read its input.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${CLAIMS_ROOT:-$(cd "$here/../../.." && pwd)}"
PLUGIN="$ROOT/plugins/decision-records"
SCRIPT="$PLUGIN/skills/decision-records/scripts/check-decisions.sh"
SKILL="$PLUGIN/skills/decision-records/SKILL.md"
TREADME="$PLUGIN/tests/README.md"

pass=0; fail=0
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT

# $1 is what RUNNING produces, $2 is what the documentation CLAIMS. The labels were the other
# way round in the first version, so a failure read "claimed=18 actual=999" with 18 being the
# measurement. A bench whose failure message names the wrong side sends the reader to correct
# the wrong file.
ok() {  # $1 measured, $2 claimed, $3 what the claim is about
    if [ "$1" = "$2" ]; then printf '  ok    %-28s %s\n' "$2" "$3"; pass=$((pass + 1))
    else printf '  FAIL  claimed=%s measured=%s  %s\n' "${2:-<nothing>}" "$1" "$3"; fail=$((fail + 1)); fi
}

# --- the measurements, taken once -------------------------------------------------------
suite_line=$(bash "$PLUGIN/tests/run.sh" 2>/dev/null | tail -1)
real_cases=$(sed -n 's/^-- \([0-9]*\) passed.*/\1/p' <<<"$suite_line")
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/stub.sh"
stub_line=$(CHECK_SCRIPT="$T/stub.sh" bash "$PLUGIN/tests/run.sh" 2>/dev/null | tail -1)
stub_pass=$(sed -n 's/^-- \([0-9]*\) passed.*/\1/p' <<<"$stub_line")
stub_fail=$(sed -n 's/.*passed, \([0-9]*\) failed.*/\1/p' <<<"$stub_line")
say_sites=$(grep -c 'say "' "$SCRIPT")
skip_sites=$(grep -c 'skipped "' "$SCRIPT")

# --- the predicates ---------------------------------------------------------------------
# Each reads the number the documentation CLAIMS, and compares it with the number produced by
# running. The claimed value is extracted by pattern, so a rewrite that drops the sentence
# makes the predicate report an empty claim rather than silently pass.
claims() {
    local r="$1" t s
    t="$r/plugins/decision-records/tests/README.md"
    s="$r/plugins/decision-records/skills/decision-records/SKILL.md"

    echo "== the tests README's numbers are the numbers running produces =="
    ok "$real_cases" "$(sed -n 's/.*turns [0-9]* of the \([0-9]*\) cases red.*/\1/p' "$t" | head -1)" 'total cases'
    ok "$stub_pass"  "$(sed -n 's/.*the \([0-9]*\) that stay green.*/\1/p' "$t" | head -1)"          'cases a stub still passes'
    ok "$stub_pass"  "$(sed -n 's/.*# -- \([0-9]*\) passed, [0-9]* failed --.*/\1/p' "$t" | head -1)" 'the pasted stub run, passed'
    ok "$stub_fail"  "$(sed -n 's/.*# -- [0-9]* passed, \([0-9]*\) failed --.*/\1/p' "$t" | head -1)" 'the pasted stub run, failed'
    ok "$stub_fail"  "$(sed -n 's/.*turns \([0-9]*\) of the [0-9]* cases red.*/\1/p' "$t" | head -1)" 'cases a stub turns red'

    echo "== and the coverage sweep's site counts =="
    # Read from the file with newlines flattened. A predicate that depends on where a sentence
    # happens to wrap breaks the next time someone reflows a paragraph, and breaks by going
    # GREEN on an empty capture, which is the direction that does not get noticed.
    local flat; flat=$(tr '\n' ' ' < "$t")
    ok "$say_sites"  "$(grep -oE 'the [0-9]+ .?say.? sites'     <<<"$flat" | grep -oE '[0-9]+' | head -1)" 'say sites named in the sweep section'
    ok "$skip_sites" "$(grep -oE 'the [0-9]+ .?skipped.? sites' <<<"$flat" | grep -oE '[0-9]+' | head -1)" 'skipped sites named in the sweep section'

    echo "== the SKILL's table of checks matches the codes the script can emit =="
    local table codes
    table=$(sed -n '/^| Code | What it catches |/,/^$/p' "$s" | grep -cE '^\| `[A-Z]+`')
    codes=$(grep -oE 'say "[A-Z]+ ' "$SCRIPT" | sed 's/.*"//;s/ *$//' | sort -u | wc -l)
    ok "$codes" "$table" 'rows in the SKILL table vs distinct codes the script emits'
    ok "$codes" "$(sed -n 's/^\([A-Z][a-z]*\) checks, each printing a stable code.*/\1/p' "$s" | head -1 | tr 'A-Z' 'a-z' | sed 's/^eight$/8/;s/^seven$/7/;s/^nine$/9/')" 'the count written in prose above that table'

    echo "== every code the script can emit also has a line saying when it cannot apply =="
    local missing=0 c
    # sed, not awk $2: `say "DRIFT ` splits into `say` and `"DRIFT`, and the quote rides along.
    # The count predicate above survived it (8 is 8 either way) while the membership one below
    # could not match a single code. A bench that reads its input wrongly is the thing a bench
    # is for, and this one reported it on its first run.
    for c in $(grep -oE 'say "[A-Z]+ ' "$SCRIPT" | sed 's/.*"//;s/ *$//' | sort -u); do
        grep -qE "skipped \"[A-Z, ()a-z]*$c" "$SCRIPT" || { missing=1; echo "     $c has no skipped() line"; }
    done
    ok 0 "$missing" 'no code can go quiet without announcing it'
}

claims "$ROOT"

# --- the counter-proof ------------------------------------------------------------------
# The same predicates, against a copy with ONE claimed number perturbed. At least one must go
# red, or the bench above has not been shown to read what it claims to read.
echo ""
echo "== counter-proof: the same predicates against a perturbed copy =="
cp -r "$ROOT/plugins" "$T/plugins"
perturbed="$T/plugins/decision-records/tests/README.md"
sed -i.bak "s/turns \([0-9]*\) of the \([0-9]*\) cases red/turns \1 of the 4242 cases red/" "$perturbed"
rm -f "$perturbed.bak"
before=$fail
claims "$T" >/dev/null 2>&1
if [ "$fail" -gt "$before" ]; then
    printf '  ok    %-28s %s\n' "$((fail - before)) red" 'a perturbed case count is caught'
    fail=$before; pass=$((pass + 1))
else
    printf '  FAIL  %-28s %s\n' 'nothing went red' 'the predicates did not read the perturbed file'
    fail=$((before + 1))
fi

printf '\n-- %d claims verified, %d wrong --\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || echo "   a number in the documentation has stopped being true."
exit $(( fail > 0 ))
