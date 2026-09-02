#!/usr/bin/env bash
# Regression tests for check-decisions.sh.
# Run after ANY change to skills/decision-records/scripts/check-decisions.sh.
#
#   bash tests/run.sh
#
# Override (for development):
#   CHECK_SCRIPT=/path/to/candidate.sh bash tests/run.sh
#
# The override is what makes this bench provable rather than decorative. Point it at a
# script that always exits 0 and the bench must go red; the README carries the one-liner.
# A bench nobody has seen fail says nothing.
#
# EVERY CHECK HAS A NEGATIVE FIXTURE HERE. That is the point of the file: a suite made only
# of cases that must pass goes green against a validator that validates nothing. Eight codes
# can each exit 1, so an exit code alone cannot say which check fired -- `because` asserts
# the code as well, the same reason .githooks/tests/run.sh has check_because.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="${CHECK_SCRIPT:-$here/../skills/decision-records/scripts/check-decisions.sh}"
[ -f "$CHECK" ] || { echo "missing: $CHECK" >&2; exit 2; }

pass=0; fail=0
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT

# A numbered Nygard collection, three accepted records and an index: the shape adr-tools
# writes. Every negative fixture below is this, with exactly one thing broken.
nygard() {
    local d="$T/$1"; mkdir -p "$d"; local i
    for i in 1 2 3; do
        cat > "$d/000$i-decision-$i.md" <<EOF
# $i. Decision $i

## Status

accepted

## Context

Something needed deciding.

## Decision

We decided $i.

## Consequences

Trade-offs follow.
EOF
    done
    {
        echo "# Decisions"
        echo ""
        for i in 1 2 3; do echo "- [000$i](000$i-decision-$i.md) Decision $i"; done
    } > "$d/README.md"
    echo "$d"
}

# A collection that is neither Nygard nor MADR: dated filenames, frontmatter status, a
# section set nobody published. Every linter in the prior art reports its convention as
# violations; this one has to accept it.
house() {
    local d="$T/$1"; mkdir -p "$d"; local x
    for x in 2026-01-04 2026-02-11 2026-03-30; do
        cat > "$d/$x-choice.md" <<EOF
---
status: accepted
---

# Choice of $x

## Why now

Because.

## What we do

This.

## What it costs

That.
EOF
    done
    echo "$d"
}

# A bold field, which is what the ECC skill writes and what most hand-rolled collections
# end up with. The other three forms are covered by nygard(), house() and bullets().
ecc() {
    local d="$T/$1"; mkdir -p "$d"; local i
    for i in 1 2; do
        cat > "$d/000$i-thing-$i.md" <<EOF
# ADR-000$i: Thing $i

**Date**: 2026-08-01
**Status**: accepted

## Context

x

## Decision

y
EOF
    done
    { echo "# ADR"; for i in 1 2; do echo "- [000$i](000$i-thing-$i.md)"; done; } > "$d/README.md"
    echo "$d"
}

# A collection whose records carry their status as a BULLET in a header list. This is what
# generator tooling emits, and the first version of the script did not know the form: every
# record in such a collection got a STATUS violation. Found in review, reproduced on four
# real collections, and 32 files on the machine where it was found.
bullets() {
    local d="$T/$1"; mkdir -p "$d"; local x
    for x in 2026-01-04 2026-02-11; do
        cat > "$d/$x-choice.md" <<EOF
# Choice of $x

- Status: accepted
- Date: $x

## Context

x

## Decision

y
EOF
    done
    echo "$d"
}

# ADR-031-slug.md: a number behind a word. The first version classified it as "no scheme"
# and switched NAME and DUPLICATE off without saying so.
prefixed() {
    local d="$T/$1"; mkdir -p "$d"; local i
    for i in 031 032; do
        printf '# ADR-%s\n\n## Status\n\naccepted\n\n## Context\n\nx\n\n## Decision\n\ny\n' "$i" > "$d/ADR-$i-thing.md"
    done
    echo "$d"
}

run() { ( bash "$CHECK" "$@" >/dev/null 2>&1 ); echo $?; }

# How many lines of the "checks that did not run" block mention $2. The block is the only
# thing standing between a check that cannot apply and a reader who reads "OK" as "checked".
skips() {  # $1 substring, then the arguments to pass to the script
    local sub="$1"; shift
    bash "$CHECK" "$@" 2>&1 >/dev/null | grep -c -- "$sub"
}

# How many violation lines of one code. An exit code cannot distinguish "reported once" from
# "reported twice", and a duplicated report reads as two defects.
count_code() {  # $1 code, then the arguments
    local code="$1"; shift
    bash "$CHECK" "$@" 2>/dev/null | grep -c "^$code "
}

ok() {  # $1 expected exit, $2 got, $3 label
    if [ "$1" = "$2" ]; then printf '  ok    %-3s %s\n' "$2" "$3"; pass=$((pass + 1))
    else printf '  FAIL  expected=%s got=%s  %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); fi
}

because() {  # $1 expected exit, $2 code the output must carry, then the arguments
    local exp="$1" code="$2"; shift 2
    local out got
    out="$(bash "$CHECK" "$@" 2>&1)"; got=$?
    if [ "$got" = "$exp" ] && printf '%s\n' "$out" | grep -q "^$code "; then
        printf '  ok    %-3s %s\n' "$got" "$code: $*"
        pass=$((pass + 1))
    elif [ "$got" = "$exp" ]; then
        printf '  FAIL  right exit %s, but no %s line  %s\n' "$got" "$code" "$*"; fail=$((fail + 1))
    else
        printf '  FAIL  expected=%s got=%s  %s\n' "$exp" "$got" "$code: $*"; fail=$((fail + 1))
    fi
}

echo "== the control: a collection that follows its own convention passes =="
d=$(nygard clean);      ok 0 "$(run "$d")" 'a clean numbered Nygard collection'
h=$(house  clean-house); ok 0 "$(run "$h")" 'a dated collection with a bespoke section set, which matches no published spec'

echo "== NAME =="
d=$(nygard name); mv "$d/0003-decision-3.md" "$d/decision-three.md"
sed -i.bak 's|0003-decision-3.md|decision-three.md|' "$d/README.md" && rm -f "$d/README.md.bak"
because 1 NAME "$d"
# No majority scheme at all: nothing to hold the records to, and saying so beats picking one.
d=$(nygard noscheme); mv "$d/0002-decision-2.md" "$d/2026-02-02-decision-2.md"; mv "$d/0003-decision-3.md" "$d/three.md"
because 1 NAME "$d"

echo "== SECTION =="
d=$(nygard section); sed -i.bak '/^## Consequences/,$d' "$d/0002-decision-2.md" && rm -f "$d"/*.bak
because 1 SECTION "$d"
# The threshold is "more than half", not the intersection of every record. Under an
# intersection a single sloppy record erases the requirement for all the others, so the
# check stops checking exactly when the collection has started to rot. This case is that
# one: 2 of 3 carry the section, so the third still owes it.
ok 1 "$(run "$d")" 'a section 2 of 3 records carry is still required of the third'
# An extra section only one record has is NOT imposed on the rest.
d=$(nygard extra); printf '\n## Notes\n\nonly here.\n' >> "$d/0001-decision-1.md"
ok 0 "$(run "$d")" 'a section only one record has is not required of the others'
# --require is the only way a rule enters that the collection is not already following.
because 1 SECTION --require "context,decision,rollback plan" "$d"

echo "== STATUS =="
d=$(nygard status); sed -i.bak '/^## Status/,/^accepted$/d' "$d/0002-decision-2.md" && rm -f "$d"/*.bak
because 1 STATUS "$d"
d=$(nygard vocab)
because 1 STATUS --status "proposed,rejected" "$d"
ok 0 "$(run --status "accepted,proposed" "$d")" 'control: the declared vocabulary that does contain the status passes'

echo "== the four status forms, and what happens when a collection uses none of them =="
# The defect this section holds down was found in review, not by this suite: the bullet form
# was unknown, so a collection using it got a STATUS violation on EVERY record. A validator
# that is wrong about every record does not get corrected, it gets switched off, and the
# other seven checks go with it. That is worse than the silent no-op in the other direction.
d=$(bullets bullet); ok 0 "$(run "$d")" 'a collection whose status is a "- Status:" bullet is clean, not a violation per record'
got=$(bash "$CHECK" "$d" 2>/dev/null | grep -c 'status form       : bullet')
ok 1 "$got" 'and the convention report names the bullet form it found'
# Exit 0 alone does NOT prove the form is read: with the form unknown, no record has a
# status, and the collection-aware rule below skips the check and exits 0 too. Measured by
# mutation: removing the bullet form from status_of left the two cases above green. The
# vocabulary line is the assertion that is actually attached to the guard, because the value
# can only appear there if status_of extracted it.
got=$(bash "$CHECK" "$d" 2>/dev/null | grep -c 'status vocabulary : accepted')
ok 1 "$got" 'and the status VALUE was read, not merely the shape recognised'
# The per-record check must still fire inside that dialect, or the fix above traded one
# blind spot for another.
sed -i.bak '/^- Status: accepted$/d' "$d/2026-02-11-choice.md" && rm -f "$d"/*.bak
because 1 STATUS "$d"
# And when NO record has a status in any known form, the honest reading is not "every
# record is broken", it is "this collection records status in a shape I do not know".
d=$(nygard nostatus); sed -i.bak '/^## Status$/,/^accepted$/d' "$d"/000*.md && rm -f "$d"/*.bak
ok 0 "$(run "$d")" 'no record carries a status in any known form: not one violation per record'
ok 1 "$(skips 'STATUS, DRIFT' "$d")" 'and the run says so, instead of letting silence read as checked'
# Declaring a vocabulary asserts that statuses exist. Silence against that assertion is a
# guard reporting clean over zero bytes read, the open defect its sibling keeps as an XFAIL.
because 1 STATUS --status "accepted,proposed" "$d"

echo "== DRIFT =="
d=$(nygard drift); sed -i.bak 's/^accepted$/Accepted/' "$d/0002-decision-2.md" && rm -f "$d"/*.bak
because 1 DRIFT "$d"
# Two supersede statuses differ in their REFERENCE, which is the point of them. Comparing
# whole status strings would call that a disagreement; comparing first words does not.
d=$(nygard drift-control)
sed -i.bak 's/^accepted$/superseded by ADR-0001/' "$d/0002-decision-2.md"
sed -i.bak 's/^accepted$/superseded by ADR-0002/' "$d/0003-decision-3.md"
rm -f "$d"/*.bak
ok 0 "$(run "$d")" 'two supersede statuses naming different records are not drift'

echo "== SUPERSEDE =="
d=$(nygard sup-dangling); sed -i.bak 's/^accepted$/superseded by ADR-0009/' "$d/0002-decision-2.md" && rm -f "$d"/*.bak
because 1 SUPERSEDE "$d"
d=$(nygard sup-silent); sed -i.bak 's/^accepted$/superseded/' "$d/0002-decision-2.md" && rm -f "$d"/*.bak
because 1 SUPERSEDE "$d"
d=$(nygard sup-link); sed -i.bak 's|^accepted$|superseded by [0009](0009-gone.md)|' "$d/0002-decision-2.md" && rm -f "$d"/*.bak
because 1 SUPERSEDE "$d"
d=$(nygard sup-link-ok); sed -i.bak 's|^accepted$|superseded by [0003](0003-decision-3.md)|' "$d/0002-decision-2.md" && rm -f "$d"/*.bak
ok 0 "$(run "$d")" 'the same link passes when the file it names is there'
d=$(nygard sup-ok); sed -i.bak 's/^accepted$/superseded by ADR-0003/' "$d/0002-decision-2.md" && rm -f "$d"/*.bak
ok 0 "$(run "$d")" 'control: a supersede reference that resolves passes'
# The word in prose owes nothing. Only a status that CLAIMS supersession owes a replacement.
d=$(nygard sup-prose); printf '\nThis supersedes nothing in particular.\n' >> "$d/0001-decision-1.md"
ok 0 "$(run "$d")" 'the word "supersedes" in prose, with no status claiming it, is not a violation'
# A bare number, with no ADR- prefix and no link. The three reference forms are claimed in
# SKILL.md, so each is pinned here rather than left to a reader's trust.
d=$(ecc bare-dangling); sed -i.bak 's/^\*\*Status\*\*: accepted$/**Status**: superseded by 0009/' "$d/0001-thing-1.md" && rm -f "$d"/*.bak
because 1 SUPERSEDE "$d"
d=$(ecc bare-ok); sed -i.bak 's/^\*\*Status\*\*: accepted$/**Status**: superseded by 0002/' "$d/0001-thing-1.md" && rm -f "$d"/*.bak
ok 0 "$(run "$d")" 'the same bare-number reference passes when it resolves'

echo "== all four status forms are read =="
# frontmatter (house), a '## Status' section (nygard), a bold field (ecc) and a bullet
# (bullets, above). A form that stopped being recognised shows up as a STATUS violation on
# a collection that is clean.
d=$(ecc bold); ok 0 "$(run "$d")" 'a bold-field collection is clean, so the form is being read'
got=$(bash "$CHECK" "$d" 2>&1 | grep -c 'status form       : bold-field')
ok 1 "$got" 'and the convention report names the form it found'

echo "== DUPLICATE =="
d=$(nygard dupe); cp "$d/0003-decision-3.md" "$d/0003-second-title.md"
echo "- [0003](0003-second-title.md) Second" >> "$d/README.md"
because 1 DUPLICATE "$d"
# Under a dated scheme the whole filename is the identifier (the log4brains answer in
# adr/madr#28), so a collision cannot happen without being the same file. Two records
# sharing a DATE is legitimate, and flagging it would be inventing a rule.
h=$(house same-day); cp "$h/2026-01-04-choice.md" "$h/2026-01-04-other-choice.md"
ok 0 "$(run "$h")" 'two dated records on the same day are not a duplicate identifier'

echo "== a scheme whose number hides behind a word, and one with no number at all =="
# ADR-031-slug.md was classified as "no scheme", which switched NAME and DUPLICATE off in
# silence. Same class as the bullet form: a closed list of shapes that is not complete.
d=$(prefixed pfx); ok 0 "$(run "$d")" 'a <prefix>-NNN-slug.md collection is a scheme, not a mess'
got=$(bash "$CHECK" "$d" 2>/dev/null | grep -c 'filename scheme   : prefixed')
ok 1 "$got" 'and it is reported as such'
cp "$d/ADR-031-thing.md" "$d/ADR-031-other.md"
because 1 DUPLICATE "$d"
# Free-form names are a legitimate convention. There is nothing to enforce, and BOTH facts
# that follow from it are said rather than passed over.
d=$(nygard freeform); for f in "$d"/000*.md; do mv "$f" "$d/$(basename "${f#*-}")"; done
sed -i.bak 's|(000[0-9]*-|(|' "$d/README.md" && rm -f "$d/README.md.bak"
ok 0 "$(run "$d")" 'free-form filenames are not a violation'
ok 1 "$(skips 'NAME:' "$d")" 'but NAME is named as not run, so the OK cannot read as "the names were checked"'
ok 1 "$(skips 'DUPLICATE:' "$d")" 'and DUPLICATE too'

echo "== a numeric supersede reference where the scheme carries no number =="
# The first version extracted the YEAR out of 2026-08-26-slug.md and resolved against it,
# so this check was not merely inapplicable there, it answered a different question.
h=$(house dated-sup); sed -i.bak 's/^status: accepted$/status: superseded by 0009/' "$h/2026-01-04-choice.md" && rm -f "$h"/*.bak
ok 0 "$(run "$h")" 'a bare number under a dated scheme is not reported as dangling'
ok 1 "$(skips 'SUPERSEDE' "$h")" 'it is named as unchecked instead'

echo "== INDEX, in both directions =="
d=$(nygard idx-unlisted); sed -i.bak '/0002-decision-2.md/d' "$d/README.md" && rm -f "$d/README.md.bak"
because 1 INDEX "$d"
d=$(nygard idx-ghost); echo "- [0004](0004-ghost.md) Ghost" >> "$d/README.md"
because 1 INDEX "$d"
# No index is legitimate: not every collection keeps one. It is SAID rather than passed
# over, because a check that quietly does not run reads as a check that passed.
d=$(nygard idx-none); rm "$d/README.md"
ok 0 "$(run "$d")" 'no index: the checks do not run, and the run stays clean'
ok 1 "$(skips 'INDEX:' "$d")" 'and it is named in "checks that did not run" instead of staying silent'

echo "== PORTABLE, opt-in =="
d=$(nygard port); printf '\nSee /home/someone/notes.md for the rest.\n' >> "$d/0001-decision-1.md"
ok 0 "$(run "$d")" 'an absolute path is not reported without --portable'
because 1 PORTABLE --portable "$d"
d=$(nygard port-link); printf '\nSee [the design](../../design/x.md).\n' >> "$d/0001-decision-1.md"
because 1 PORTABLE --portable "$d"
d=$(nygard port-clean)
ok 0 "$(run --portable "$d")" 'control: --portable on a clean collection passes'

echo "== a verdict of 0 over nothing checked is the one thing it must not fake =="
mkdir -p "$T/empty"
ok 2 "$(run "$T/empty")" 'an empty directory exits 2, not a clean 0'
mkdir -p "$T/only-furniture"; printf '# Index\n' > "$T/only-furniture/README.md"; printf '# T\n' > "$T/only-furniture/template.md"
ok 2 "$(run "$T/only-furniture")" 'a directory holding only an index and a template exits 2: neither is a record'
ok 2 "$(run "$T/does-not-exist")" 'a directory that is not there exits 2'
ok 2 "$(run)" 'no arguments exits 2'
ok 2 "$(run --require)" 'an option missing its value exits 2'
ok 2 "$(run --bogus "$T/empty")" 'an unknown option exits 2 instead of being ignored'
d=$(nygard twoargs); ok 2 "$(run "$d" "$d")" 'two directories at once exits 2 rather than silently checking one'

echo "== the shapes an independent review found, each with the case it needs =="
# Every case here holds down a defect that shipped in the first version and was found by a
# fresh-context reading of the diff, not by this suite. They are grouped so that a later
# reader can see what a review buys that a self-written bench does not.

# An empty '## Status' section: the reader grabbed the first non-blank line after the
# heading with no stop at the next one, so the status VALUE became '## Context'. The check
# could not fire and the convention report was poisoned with it.
d=$(nygard emptystatus)
printf '# 2\n\n## Status\n\n## Context\n\nx\n\n## Decision\n\ny\n\n## Consequences\n\nz\n' > "$d/0002-decision-2.md"
because 1 STATUS "$d"
got=$(bash "$CHECK" "$d" 2>/dev/null | grep -c 'status vocabulary : accepted$')
ok 1 "$got" 'and the empty section does not leak a heading into the deduced vocabulary'

# A heading with two consecutive spaces. The majority vote rebuilt each heading through awk
# with a single-space OFS while the per-record set kept both, so the exact match failed on
# EVERY record of a collection that agreed with itself perfectly.
d=$(nygard doublespace)
for f in "$d"/000*.md; do sed -i.bak 's/^## Context$/## Context and  motivation/' "$f"; done
rm -f "$d"/*.bak
ok 0 "$(run "$d")" 'a heading carrying two consecutive spaces is not a violation on every record'

# log4brains, the tool that adopted a date prefix in adr/madr#28 precisely to kill the
# numbering collision, writes the COMPACT date. Accepting only YYYY-MM-DD sent it to the
# numbered branch, where two records written on one day became a DUPLICATE: the exact rule
# this suite pins as one that must never be invented.
d="$T/compact"; mkdir -p "$d"
for x in 20201211 20201214 20201221; do
    printf -- '---\nstatus: accepted\n---\n\n# %s\n\n## Context\n\nx\n\n## Decision\n\ny\n' "$x" > "$d/$x-decision.md"
done
cp "$d/20201211-decision.md" "$d/20201211-second-same-day.md"
ok 0 "$(run "$d")" 'two compact-date records on the same day are not a duplicate identifier'
got=$(bash "$CHECK" "$d" 2>/dev/null | grep -c 'filename scheme   : dated')
ok 1 "$got" 'and the compact form is recognised as dated, not as record number 20201211'

# The dated NAME guard was the ONE say() site in the script with no case attached to it.
# The reviewer found it by disabling all fifteen sites one at a time; nothing else could
# have, which is the argument for doing that rather than reading the file again.
h=$(house dated-name)
printf -- '---\nstatus: accepted\n---\n\n# Loose\n\n## Why now\n\nb\n\n## What we do\n\nt\n\n## What it costs\n\nc\n' > "$h/loose-note.md"
because 1 NAME "$h"

# A bare absolute path, with nothing after it. The pattern required a trailing slash, so
# the shape a sentence actually uses went unreported.
d=$(nygard bareabs); printf '\nThe workspace is /home/someuser and nothing follows it.\n' >> "$d/0001-decision-1.md"
because 1 PORTABLE --portable "$d"

# README.md won the index race unconditionally, so a collection whose index is index.md and
# whose README.md is prose had every record reported as unindexed.
d=$(nygard twofiles); rm "$d/README.md"
printf '# About these decisions\n\nProse, and not a single link.\n' > "$d/README.md"
{ echo "# Index"; for i in 1 2 3; do echo "- [000$i](000$i-decision-$i.md)"; done; } > "$d/index.md"
ok 0 "$(run "$d")" 'the index is the file that links to records, not the first candidate that exists'

# Reference-style links are ordinary markdown, and the parser knew only the inline shape.
d=$(nygard refstyle)
{ echo "# Decisions"; echo ""
  for i in 1 2 3; do echo "- [000$i][r$i]"; done; echo ""
  for i in 1 2 3; do echo "[r$i]: 000$i-decision-$i.md"; done; } > "$d/README.md"
ok 0 "$(run "$d")" 'an index written with reference-style links is read, not reported as empty'
# Exit 0 alone does not prove the parser read it: with the reference-style branch removed
# the index carries no links, the candidate is skipped as not-an-index, the INDEX check is
# skipped too, and the run exits 0 for a different reason. Measured by mutation, which is the
# only thing that could have caught two fixes masking each other. Asserting the check RAN is
# what attaches this case to the parser.
ok 0 "$(skips 'INDEX:' "$d")" 'and the INDEX check actually ran against it, rather than being skipped'

# basename() collapsed the path, so a link climbing out of the collection resolved against a
# same-named record inside it. The link and the portability of the link are two questions.
d=$(nygard outlink)
sed -i.bak 's|^accepted$|superseded by [0003](../../elsewhere/0003-decision-3.md)|' "$d/0001-decision-1.md"
rm -f "$d"/*.bak
because 1 SUPERSEDE "$d"

echo "== round three: what a second independent review found in the CORRECTIONS =="
# Every case below holds down a defect introduced by a FIX for an earlier defect. Two of
# them are the earlier defect restored in the other half of the code. That is the pattern
# worth naming: a correction is new code, and new code is where the next defect goes.

# The index race, restored. The fix said "the candidate that links to RECORDS" and the code
# said "carries any .md link", so one ordinary link in a prose README beat the real index.
# The old fixture used a README with NO links, the single case the defect does not cover.
d=$(nygard idxrace); rm "$d/README.md"
printf '# About these decisions\n\nProse. See [the guide](../CONTRIBUTING.md) to contribute.\n' > "$d/README.md"
{ echo "# Index"; for i in 1 2 3; do echo "- [000$i](000$i-decision-$i.md)"; done; } > "$d/index.md"
ok 0 "$(run "$d")" 'a prose README carrying an unrelated .md link does not beat the real index.md'

# basename() collapsing, fixed in SUPERSEDE and left in the index parser. Both directions.
d=$(nygard idxbase); mkdir -p "$d/../elsewhere-$$"
{ echo "# Decisions"; echo "- [0001](0001-decision-1.md)"; echo "- [0002](0002-decision-2.md)"
  echo "- [0003](../elsewhere-$$/0003-decision-3.md)"; } > "$d/README.md"
because 1 INDEX "$d"
d=$(nygard idxout); mkdir -p "$d/../docs-$$"; printf '# design\n' > "$d/../docs-$$/design.md"
{ echo "# Decisions"; for i in 1 2 3; do echo "- [000$i](000$i-decision-$i.md)"; done
  echo "See also [the design notes](../docs-$$/design.md)."; } > "$d/README.md"
ok 0 "$(run "$d")" 'an index link out of the collection that does resolve is not dangling'

# The prefixed NAME guard shipped with no case, which is the SAME defect the previous review
# found on the dated branch. A correction that adds a say site owes it a fixture.
d=$(prefixed pfxname)
printf '# loose\n\n## Status\n\naccepted\n\n## Context\n\nx\n\n## Decision\n\ny\n' > "$d/loose-note.md"
because 1 NAME "$d"

# "- **Status:** accepted": the closing emphasis landed inside the value, the vocabulary
# became "**", and --status then fired on every record of a legitimate collection.
d=$(mktemp -d "$T/boldbullet.XXXX")
for i in 1 2 3; do printf '# %s\n\n- **Status:** accepted\n- **Date:** 2026-01-0%s\n\n## Context\n\nx\n\n## Decision\n\ny\n' "$i" "$i" > "$d/000$i-d$i.md"; done
ok 0 "$(run --status "accepted,proposed" "$d")" 'a "- **Status:** value" bullet yields the value, not the emphasis'
got=$(bash "$CHECK" "$d" 2>/dev/null | grep -c 'status vocabulary : accepted$')
ok 1 "$got" 'and the deduced vocabulary is the status, not a run of asterisks'

# A level-3 heading under ## Status leaked exactly like the level-2 one the earlier fix
# stopped at. Stopping at "^#" closes the family instead of one member of it.
d=$(nygard h3)
for f in "$d"/000*.md; do sed -i.bak 's/^accepted$/### Accepted/' "$f"; done; rm -f "$d"/*.bak
got=$(bash "$CHECK" "$d" 2>/dev/null | grep -c 'status vocabulary : none found')
ok 1 "$got" 'a level-3 heading does not leak into the status value'

# SECTION could silently not run, in the one block whose stated job is to say what did not.
d=$(mktemp -d "$T/nosections.XXXX")
i=0
for s in alpha beta gamma; do i=$((i + 1)); printf -- '---\nstatus: accepted\n---\n\n# %s\n\n## %s\n\nx\n' "$s" "$s" > "$d/000$i-$s.md"; done
ok 0 "$(run "$d")" 'a collection where no heading reaches the majority is not a violation'
ok 1 "$(skips 'SECTION:' "$d")" 'but SECTION is named as not run, like every other check that cannot apply'
# And --require resolving to nothing is a statement about the INVOCATION, not the collection.
because 1 SECTION --require "," "$d"

# A prefix is a scheme only if the collection SHARES it. Matching the shape alone read
# free-form titles as numbered and invented the DUPLICATE the README forbids inventing.
d=$(mktemp -d "$T/freetitles.XXXX")
for x in use-2-phase-commit move-2-week-sprints adopt-3-tier-architecture; do
    printf '# %s\n\n## Status\n\naccepted\n\n## Context\n\nx\n\n## Decision\n\ny\n' "$x" > "$d/$x.md"
done
ok 0 "$(run "$d")" 'free-form titles carrying a digit are not a prefixed scheme, and not a duplicate'
got=$(bash "$CHECK" "$d" 2>/dev/null | grep -c 'filename scheme   : free-form')
ok 1 "$got" 'they are reported as free-form'

# --portable fired on any URL carrying a /home/ path segment.
d=$(nygard porturl); printf '\nSee https://docs.example.com/home/getting-started for the rationale.\n' >> "$d/0001-decision-1.md"
ok 0 "$(run --portable "$d")" 'a URL with a /home/ segment is not an absolute path on this machine'
printf '\nThe workspace is /home/someuser here.\n' >> "$d/0002-decision-2.md"
because 1 PORTABLE --portable "$d"

# An index that documents its own row format had its example reported as a dead link.
d=$(nygard idxfence)
{ echo "# Decisions"; for i in 1 2 3; do echo "- [000$i](000$i-decision-$i.md)"; done
  echo; echo "To add one, append a row like:"; echo; echo '"'"'```markdown'"'"'
  echo "- [0004](0004-your-decision.md)"; echo '"'"'```'"'"'; } > "$d/README.md"
ok 0 "$(run "$d")" "an index's own fenced example is not a link to a missing file"

echo "== five guards the suite was not holding, found by mutating what the table does not cover =="
# One dangling reference reported twice reads as two defects. The status line is in the scan
# twice over when the collection keeps its status in a section.
d=$(nygard dupreport); sed -i.bak 's|^accepted$|superseded by [0009](0009-gone.md)|' "$d/0001-decision-1.md"; rm -f "$d"/*.bak
ok 1 "$(count_code SUPERSEDE "$d")" 'a single dangling supersede reference is reported once, not twice'

# A record that merely SHOWS the convention in a fenced block must not satisfy it. The file
# argues this at length and nothing pinned it.
d=$(nygard fenced)
printf '# 2\n\n## Status\n\naccepted\n\n## Context\n\nLike this:\n\n```markdown\n## Consequences\n\nnot a real section\n```\n\n## Decision\n\ny\n' > "$d/0002-decision-2.md"
because 1 SECTION "$d"
# Same hole through an INDENTED block, which is four spaces and is code by the markdown rule.
d=$(bullets indented)
printf '# 3\n\n## Context\n\nOur house template is:\n\n    - Status: proposed\n\n## Decision\n\ny\n' > "$d/2026-03-30-choice.md"
because 1 STATUS "$d"

# --require is matched against headings that were lowercased; the declaration must be too.
d=$(nygard reqcase)
ok 0 "$(run --require "Context,Decision" "$d")" 'a --require written in title case matches the deduced lowercase headings'

# The reverse index check must skip the furniture it excluded from the records, or an index
# that links its own template reports it as a missing record.
d=$(nygard idxtemplate); echo "- [template](template.md)" >> "$d/README.md"
ok 0 "$(run "$d")" 'an index linking a template.md that is not on disk is not a dangling record link'

# Headings written with a trailing colon are the same heading.
d=$(nygard coloned)
sed -i.bak -e 's/^## Context$/## Context:/' -e 's/^## Decision$/## Decision:/' "$d/0002-decision-2.md"; rm -f "$d"/*.bak
ok 0 "$(run "$d")" 'a heading written "## Context:" is the same section as "## Context"'

echo "== the promise that every check says when it cannot apply, checked mechanically =="
# SKILL.md states it as a universal. A universal in prose is exactly what rots without
# anyone noticing, so it is asserted against the script instead of trusted: every violation
# code must also appear in a skipped() line, or a check can go quiet with nothing saying so.
for code in NAME SECTION STATUS DRIFT SUPERSEDE DUPLICATE INDEX PORTABLE; do
    got=$(grep -c "skipped \"[A-Z, ]*$code" "$here/../skills/decision-records/scripts/check-decisions.sh")
    [ "$got" -gt 0 ] && got=1
    ok 1 "$got" "$code has a 'checks that did not run' line for the case where it cannot apply"
done

echo "== the template and the index are not records =="
d=$(nygard furniture); printf -- '---\nstatus: x\n---\n# T\n\n## Placeholder\n' > "$d/template.md"
ok 0 "$(run "$d")" 'a template.md beside the records is excluded, not validated as one'

printf '\n-- %d passed, %d failed --\n' "$pass" "$fail"
exit $(( fail > 0 ))
