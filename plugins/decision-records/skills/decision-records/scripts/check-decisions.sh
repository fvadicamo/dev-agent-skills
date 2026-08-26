#!/usr/bin/env bash
# Validate a collection of decision records against the convention THAT COLLECTION
# already follows, rather than against a published spec it may never have adopted.
#
# check-decisions.sh 0.1.0 -- canonical copy: decision-records skill (dev-agent-skills),
# skills/decision-records/scripts/check-decisions.sh. Run in place. Unlike privacy-guard's
# check_privacy.sh this script is NOT copied into the repos it inspects, so there is no
# second copy to drift: the version line above is provenance, not a sync marker.
#
#   check-decisions.sh [--require "A,B"] [--status "a,b"] [--portable] DIR
#
#   --require "A,B"   the required sections, instead of deducing them
#   --status  "a,b"   the admitted status vocabulary, instead of only checking drift
#   --portable        also run the portability checks (see PORTABLE below)
#
# Exit codes: 0 clean, 1 violations found, 2 usage error or nothing to check.
#
# Every violation line starts with a stable CODE, so a caller (and the bench) can tell
# which check fired. Eight different checks exit 1, and an exit code alone cannot say which:
#
#   NAME       filename does not follow the collection's own scheme
#   SECTION    a section that most records carry is missing from this one
#   STATUS     a record with no status, in a collection whose other records have one
#   DRIFT      two records spell the same status differently (Accepted vs accepted)
#   SUPERSEDE  a supersede reference resolves to nothing, or names no replacement
#   DUPLICATE  two records claim the same identifier
#   INDEX      the index and the directory disagree, in either direction
#   PORTABLE   content that breaks when the record is copied to another repo
#
# WHY DEDUCE. The linters in the field (mdbook-lint's ADR rules, madr-lint, adrkit) all
# validate against a published spec: Nygard, or MADR v2/v3/v4, chosen by auto-detection
# between those. A collection whose house convention is neither -- a date-prefixed filename
# with a bespoke section set -- gets its own convention reported as violations by every one
# of them. This script asks the collection what it does, and holds it to that.
#
# WHAT IT WILL NOT DO. It never rewrites a record and never creates one. Writing is the
# skill's job, and only after the user has approved a draft.

set -uo pipefail

REQUIRE=""
STATUS_VOCAB=""
PORTABLE=0
DIR=""

usage() {
    echo "Usage: $0 [--require \"A,B\"] [--status \"a,b\"] [--portable] DIR" >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --require) [ "$#" -ge 2 ] || usage; REQUIRE="$2"; shift 2 ;;
        --status)  [ "$#" -ge 2 ] || usage; STATUS_VOCAB="$2"; shift 2 ;;
        --portable) PORTABLE=1; shift ;;
        -h|--help) usage ;;
        -*) echo "unknown option: $1" >&2; usage ;;
        *) [ -z "$DIR" ] || { echo "one directory at a time: $DIR and $1" >&2; usage; }
           DIR="$1"; shift ;;
    esac
done

[ -n "$DIR" ] || usage
[ -d "$DIR" ] || { echo "not a directory: $DIR" >&2; exit 2; }

T=$(mktemp -d "${TMPDIR:-/tmp}/check-decisions.XXXXXX") || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/sec"

lower() { tr '[:upper:]' '[:lower:]'; }

# The record body: frontmatter and fenced code removed. Both matter. A '## Context' inside a
# fenced example is not a section of this record, and counting it would let a record that
# merely SHOWS the convention satisfy it.
body_of() {
    awk '
        NR == 1 && $0 == "---" { fm = 1; next }
        fm && $0 == "---"      { fm = 0; next }
        fm                     { next }
        /^[[:space:]]*```/     { fence = !fence; next }
        fence                  { next }
        { print }
    ' "$1"
}

frontmatter_of() {
    awk '
        NR == 1 && $0 == "---" { fm = 1; next }
        fm && $0 == "---"      { exit }
        fm                     { print }
    ' "$1"
}

# Runs of whitespace are squeezed to one space. Not cosmetic: the majority-vote below
# rebuilds each heading through awk with a single-space OFS, so '## Context and  motivation'
# arrived in the required set with one space and in the per-record set with two, and the
# exact-match test then failed on EVERY record of a collection that was perfectly
# consistent with itself. That is the failure this whole script exists to avoid, produced
# by the script itself.
headings_of() { body_of "$1" | grep -E '^##[[:space:]]+' | sed -e 's/^##*[[:space:]]*//' -e 's/[[:space:]][[:space:]]*/ /g' -e 's/[[:space:]]*:*[[:space:]]*$//' | lower | sort -u; }

# The status value, tried in the four forms seen in the field, in this order:
#   frontmatter `status:`         MADR 4.0.0
#   `- Status: value`             a bullet in a header list: what generator tooling emits
#   `**Status**: value`           the ECC skill, and most hand-rolled collections
#   a `## Status` section         Nygard, and what adr-tools writes
# Prints nothing when none is present. That is a finding about the RECORD only when other
# records in the same collection do have one; see the STATUS check for why.
#
# The bullet form was missing from the first version, and the way it was missing is the
# point. A collection that used it got a STATUS violation on EVERY record: the validator
# did to that collection exactly what this tool exists to stop the spec-bound linters from
# doing, and a tool that is wrong about every record does not get corrected, it gets
# switched off, taking the other seven checks with it. Measured on this machine: 32 files
# in that form. Adding a fourth shape is the smaller half of the fix; the larger half is
# that no fixed list of shapes can be complete, which is what the STATUS check now assumes.
#
# `sed //I` is a GNU extension and this has to run on macOS too, so the case-insensitive
# part is grep's job and sed only trims what grep already selected.
status_of() {
    local v
    v=$(frontmatter_of "$1" | grep -iE '^[[:space:]]*status:' | head -1 | sed 's/^[^:]*:[[:space:]]*//')
    [ -n "$v" ] || v=$(body_of "$1" | grep -iE '^[[:space:]]*[-*+][[:space:]]+(\*\*)?status(\*\*)?[[:space:]]*:' | head -1 | sed 's/^[^:]*:[[:space:]]*//')
    [ -n "$v" ] || v=$(body_of "$1" | grep -iE '^[[:space:]]*\*\*Status\*\*[[:space:]]*:' | head -1 | sed 's/^[^:]*:[[:space:]]*//')
    [ -n "$v" ] || v=$(body_of "$1" | awk '
        tolower($0) ~ /^##[[:space:]]+status[[:space:]]*$/ { grab = 1; next }
        grab && /^##[[:space:]]/ { exit }
        grab && /^[[:space:]]*$/ { next }
        grab { print; exit }
    ')
    printf '%s' "$v" | sed -e 's/^["'"'"']//' -e 's/["'"'"']$//' -e 's/[[:space:]]*$//'
}

# The .md files an index links to, as basenames. Two shapes, because both are legitimate
# markdown and a parser that knows one reports every record of a collection using the other
# as missing:
#   inline            [0001](0001-slug.md)
#   reference-style   [0001][a]   ...   [a]: 0001-slug.md
index_links() {
    {
        grep -oE '\]\([^)]+\)' "$1" | sed -e 's/^](//' -e 's/)$//'
        grep -oE '^[[:space:]]*\[[^]]+\][[:space:]]*:[[:space:]]*[^[:space:]]+' "$1" | sed 's/.*][[:space:]]*:[[:space:]]*//'
    } 2>/dev/null | sed -e 's/#.*$//' -e 's/[[:space:]].*$//' \
        | grep -E '\.md$' | grep -v '://' | sed -e 's|.*/||' | sort -u
}

status_form_of() {
    if frontmatter_of "$1" | grep -qiE '^[[:space:]]*status:'; then echo frontmatter
    elif body_of "$1" | grep -qiE '^[[:space:]]*[-*+][[:space:]]+(\*\*)?status(\*\*)?[[:space:]]*:'; then echo bullet
    elif body_of "$1" | grep -qiE '^[[:space:]]*\*\*Status\*\*[[:space:]]*:'; then echo bold-field
    elif body_of "$1" | grep -qiE '^##[[:space:]]+status[[:space:]]*$'; then echo section
    else echo none; fi
}

# --- the records ------------------------------------------------------------------------
# A template is not a record and an index is not a record. Both are excluded by NAME, which
# is the one exclusion list in here: it names the two files every collection in the prior
# art puts beside its records (adr-tools writes template.md, the ECC skill writes both).
records=""
n=0
for f in "$DIR"/*.md; do
    [ -e "$f" ] || continue
    case "$(basename "$f" | lower)" in
        readme.md|index.md|template.md) continue ;;
    esac
    records="$records$f"$'\n'
    n=$((n + 1))
done

# Silence here would read as "clean", over zero records. It is the one verdict this script
# must never fake: a caller that only reads the exit code cannot tell a clean collection
# from a directory it failed to find anything in.
if [ "$n" -eq 0 ]; then
    echo "check-decisions.sh: no decision records in $DIR (index and template excluded), nothing was checked." >&2
    exit 2
fi

# --- deduce the filename scheme ----------------------------------------------------------
# Order matters twice over. Dated is tested first, or 2026-08-26-slug.md reads as record
# number 2026. Prefixed comes before numbered because ADR-031-slug.md carries its number
# behind a word, and the first version of this classified it as `other` -- which cost
# nothing visible and silently switched off both NAME and DUPLICATE for every collection
# using it. That form is in the field on this machine.
# Both date shapes. log4brains, the tool that adopted a date prefix in adr/madr#28 to kill
# the numbering collision, writes the COMPACT form: 20201211-title.md. Accepting only
# YYYY-MM-DD sent those straight into the numbered branch, where the identifier became
# 20201211 and two records written on one day were reported as a duplicate -- inventing
# exactly the rule the tests README says this must never invent.
RE_DATED='^([0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{8})[-_].+\.md$'
RE_PREFIXED='^[A-Za-z]+[-_][0-9]+[-_].+\.md$'
RE_NUMBERED='^[0-9]+[-_].+\.md$'

dated=0; prefixed=0; numbered=0; other=0
while IFS= read -r f; do
    [ -n "$f" ] || continue
    b=$(basename "$f")
    if   printf '%s' "$b" | grep -qE "$RE_DATED";    then dated=$((dated + 1))
    elif printf '%s' "$b" | grep -qE "$RE_PREFIXED"; then prefixed=$((prefixed + 1))
    elif printf '%s' "$b" | grep -qE "$RE_NUMBERED"; then numbered=$((numbered + 1))
    else other=$((other + 1)); fi
done <<EOF
$records
EOF

# A strict plurality, not just the largest count: with a tie there is no convention to hold
# anyone to, and saying so beats picking a winner by the order of an if.
scheme=""; scheme_count=0
for cand in dated prefixed numbered other; do
    eval "c=\$$cand"
    best=1
    for o in dated prefixed numbered other; do
        [ "$o" = "$cand" ] && continue
        eval "oc=\$$o"
        [ "$c" -gt "$oc" ] || best=0
    done
    if [ "$best" = 1 ]; then
        [ "$cand" = other ] && scheme=free || scheme="$cand"
        scheme_count=$c
        break
    fi
done

# --- deduce the required sections --------------------------------------------------------
i=0
while IFS= read -r f; do
    [ -n "$f" ] || continue
    i=$((i + 1))
    headings_of "$f" > "$T/sec/$i"
done <<EOF
$records
EOF

if [ -n "$REQUIRE" ]; then
    printf '%s' "$REQUIRE" | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
        | lower | grep -v '^$' | sort -u > "$T/required"
    required_how="declared with --require"
else
    # Present in MORE THAN HALF the records. Intersection was the first shape and it is
    # wrong in a way that matters: one sloppy record erases the requirement for every other
    # one, so the check quietly stops checking exactly when the collection needs it.
    cat "$T"/sec/* 2>/dev/null | sort | uniq -c | awk -v n="$n" '$1 * 2 > n { $1 = ""; sub(/^ +/, ""); print }' \
        | sort -u > "$T/required"
    required_how="deduced: present in more than half of $n records"
fi

# --- collect statuses --------------------------------------------------------------------
: > "$T/statuses"
i=0
while IFS= read -r f; do
    [ -n "$f" ] || continue
    i=$((i + 1))
    printf '%s\t%s\n' "$f" "$(status_of "$f")" >> "$T/statuses"
done <<EOF
$records
EOF

# The pipeline goes on the `done` line, not after the heredoc terminator: written the other
# way `sort` is a separate command inheriting the caller's stdin, and the script hangs
# waiting on a terminal instead of reading the loop's output.
dominant_form=$(while IFS= read -r f; do [ -n "$f" ] && status_form_of "$f"; done <<EOF | sort | uniq -c | sort -rn | head -1 | awk '{print $2}'
$records
EOF
)

vocab=$(cut -f2 "$T/statuses" | awk '{print $1}' | grep -v '^$' | lower | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//')

# --- the index ---------------------------------------------------------------------------
# The index is the candidate that actually LINKS to records, not the first one that exists.
# A collection whose index is index.md and whose README.md is prose about the collection is
# an ordinary shape, and picking README.md there reported every record as unindexed.
index=""
for cand in "$DIR/README.md" "$DIR/readme.md" "$DIR/index.md"; do
    [ -f "$cand" ] || continue
    [ -n "$(index_links "$cand")" ] || continue
    index="$cand"; break
done

# --- report the convention before judging anything against it ----------------------------
echo "Collection: $DIR ($n records)"
case "$scheme" in
    "")       printf '  filename scheme   : none agreed on (%d dated, %d prefixed, %d numbered, %d other)\n' "$dated" "$prefixed" "$numbered" "$other" ;;
    free)     printf '  filename scheme   : free-form, no shared pattern (%d of %d)\n' "$scheme_count" "$n" ;;
    dated)    printf '  filename scheme   : dated, YYYY-MM-DD-slug.md or YYYYMMDD-slug.md (%d of %d)\n' "$scheme_count" "$n" ;;
    numbered) printf '  filename scheme   : numbered, NNNN-slug.md (%d of %d)\n' "$scheme_count" "$n" ;;
    prefixed) printf '  filename scheme   : prefixed, <prefix>-NNN-slug.md (%d of %d)\n' "$scheme_count" "$n" ;;
esac
printf '  status form       : %s\n' "${dominant_form:-none}"
printf '  status vocabulary : %s\n' "${vocab:-none found}"
printf '  required sections : %s [%s]\n' "$(tr '\n' ',' < "$T/required" | sed -e 's/,/, /g' -e 's/, $//')" "$required_how"
printf '  index             : %s\n' "${index:-none found}"
echo ""

violations=0
say() { echo "$*"; violations=$((violations + 1)); }

# A check that quietly does not run reads, to anyone looking at the exit code, exactly like
# a check that passed. Every check that cannot apply to this collection says so here, and
# the list is printed before the verdict. This is the class of defect that produced both of
# the ones found in review: a free-form naming scheme turned NAME and DUPLICATE off in
# silence, and there is no reason to think those were the last two.
: > "$T/skipped"
skipped() { printf '  %s\n' "$*" >> "$T/skipped"; }

# The identifier a record claims, under the scheme this collection actually uses. Under a
# dated scheme the whole filename is the identifier (the log4brains answer in adr/madr#28),
# so there is nothing to extract and nothing that can collide.
id_of() {
    case "$scheme" in
        numbered) basename "$1" | sed -n 's/^0*\([0-9][0-9]*\)[-_].*/\1/p' ;;
        prefixed) basename "$1" | sed -n 's/^[A-Za-z]*[-_]0*\([0-9][0-9]*\)[-_].*/\1/p' ;;
    esac
}

# --- NAME --------------------------------------------------------------------------------
case "$scheme" in
    "")
        say "NAME $DIR: the collection does not agree on a filename scheme ($dated dated, $prefixed prefixed, $numbered numbered, $other neither); there is nothing to hold the records to."
        skipped "DUPLICATE: no agreed scheme, so no identifier to compare."
        ;;
    free)
        # Free-form names are a legitimate convention (adr/madr#28 lists `title.md`, and
        # published collections use it). There is simply no pattern to enforce, and no
        # number to collide. Both facts are said rather than left to a silent pass.
        skipped "NAME: this collection uses free-form filenames, so there is no scheme to check against."
        skipped "DUPLICATE: free-form filenames carry no identifier to compare."
        ;;
    dated)
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            printf '%s' "$(basename "$f")" | grep -qE "$RE_DATED" \
                || say "NAME $f: not YYYY-MM-DD-slug.md, which $scheme_count of $n records use."
        done <<EOF
$records
EOF
        skipped "DUPLICATE: under a dated scheme the whole filename is the identifier, so two records cannot collide without being the same file."
        ;;
    numbered)
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            b=$(basename "$f")
            if ! printf '%s' "$b" | grep -qE "$RE_NUMBERED" || printf '%s' "$b" | grep -qE "$RE_DATED"; then
                say "NAME $f: not NNNN-slug.md, which $scheme_count of $n records use."
            fi
        done <<EOF
$records
EOF
        ;;
    prefixed)
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            printf '%s' "$(basename "$f")" | grep -qE "$RE_PREFIXED" \
                || say "NAME $f: not <prefix>-NNN-slug.md, which $scheme_count of $n records use."
        done <<EOF
$records
EOF
        ;;
esac

# --- SECTION -----------------------------------------------------------------------------
if [ -s "$T/required" ]; then
    i=0
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        i=$((i + 1))
        while IFS= read -r sec; do
            [ -n "$sec" ] || continue
            grep -qxF "$sec" "$T/sec/$i" || say "SECTION $f: no '$sec' section, and $required_how."
        done < "$T/required"
    done <<EOF
$records
EOF
fi

# --- STATUS and DRIFT --------------------------------------------------------------------
# The whole check is conditioned on the COLLECTION, not on each record in isolation, and
# that is the correction the review forced. A record with no recognisable status is out of
# step only when its neighbours have one. When NO record has one, the honest reading is not
# "every record is broken", it is "this collection records status in a shape I do not know,
# or does not record it": no fixed list of four shapes is ever complete. Reporting a
# violation per record there is the failure that gets a tool switched off rather than
# corrected, and it takes the other seven checks with it.
with_status=$(awk -F'\t' '$2 != "" { c++ } END { print c + 0 }' "$T/statuses")

if [ "$with_status" -eq 0 ]; then
    skipped "STATUS, DRIFT: no record here carries a status in a form this script knows (frontmatter 'status:', a '- Status:' bullet, '**Status**:', a '## Status' section)."
    # Declaring a vocabulary asserts that statuses exist. Silence against that assertion
    # would be a guard reporting clean over zero bytes read, which is the open defect its
    # sibling privacy-guard keeps as an XFAIL rather than pretend otherwise.
    [ -n "$STATUS_VOCAB" ] && say "STATUS $DIR: --status declares the vocabulary ($STATUS_VOCAB), but no record carries a status in any recognised form, so the declaration holds nothing."
else
    while IFS=$'\t' read -r f v; do
        [ -n "$f" ] || continue
        [ -n "$v" ] || say "STATUS $f: no status, while $with_status of $n records in this collection have one."
    done < "$T/statuses"

    if [ -n "$STATUS_VOCAB" ]; then
        printf '%s' "$STATUS_VOCAB" | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | lower | grep -v '^$' | sort -u > "$T/vocab"
        while IFS=$'\t' read -r f v; do
            [ -n "$f" ] && [ -n "$v" ] || continue
            key=$(printf '%s' "$v" | awk '{print tolower($1)}')
            grep -qxF "$key" "$T/vocab" || say "STATUS $f: status '$v' is outside the declared vocabulary ($STATUS_VOCAB)."
        done < "$T/statuses"
    fi

    # Two spellings of one status. Comparing only the FIRST word is what keeps 'superseded
    # by 0003' and 'superseded by 0005' from reading as a disagreement: they differ in the
    # reference, which is the point of them, not in the status.
    cut -f2 "$T/statuses" | awk '{print $1}' | grep -v '^$' | sort -u > "$T/firstwords"
    while IFS= read -r w; do
        [ -n "$w" ] || continue
        variants=$(awk -v k="$(printf '%s' "$w" | lower)" 'tolower($0) == k' "$T/firstwords" | tr '\n' ' ' | sed 's/[[:space:]]*$//')
        count=$(printf '%s\n' "$variants" | wc -w | tr -d ' ')
        [ "$count" -gt 1 ] && say "DRIFT $DIR: the same status is spelled $count ways ($variants); pick one."
    done < <(cut -f2 "$T/statuses" | awk '{print tolower($1)}' | grep -v '^$' | sort -u)
fi

# --- DUPLICATE ---------------------------------------------------------------------------
# Only where the scheme carries a number. The schemes that do not are named in the skipped
# list above rather than passed over, because a check that cannot fail is not a check and
# a check that quietly did not run is worse: it reads as one that passed.
: > "$T/dupes"
case "$scheme" in
    numbered|prefixed)
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            id_of "$f"
        done <<EOF | sort | uniq -d > "$T/dupes"
$records
EOF
        ;;
esac
while IFS= read -r d; do
    [ -n "$d" ] || continue
    files=$(while IFS= read -r f; do
        [ -n "$f" ] || continue
        [ "$(id_of "$f")" = "$d" ] && basename "$f"
    done <<EOF
$records
EOF
)
    say "DUPLICATE $DIR: identifier $d is claimed by $(printf '%s' "$files" | tr '\n' ' ')"
done < "$T/dupes"

# --- SUPERSEDE ---------------------------------------------------------------------------
resolve_num() {  # $1 = a bare number -> prints the record that owns it, or nothing
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        id=$(id_of "$f")
        [ -n "$id" ] && [ "$id" = "$(printf '%s' "$1" | sed 's/^0*//')" ] && { printf '%s' "$f"; return; }
    done <<EOF
$records
EOF
}

numeric_refs_unresolvable=0
while IFS=$'\t' read -r f v; do
    [ -n "$f" ] || continue
    lines=$(printf '%s\n' "$v"; body_of "$f" | grep -iE 'supersed')
    printf '%s\n' "$lines" | grep -qiE 'supersed' || continue

    # sort -u, because the status line is in $lines twice over: once as the status value and
    # once from the body scan, when the collection keeps its status in a '## Status'
    # section. Without it a single dangling reference is reported twice and reads as two.
    refs=$(printf '%s\n' "$lines" | grep -oE '\]\([^)]+\.md[^)]*\)' | sed -e 's/^](//' -e 's/)$//' -e 's/#.*$//' | sort -u)
    nums=$(printf '%s\n' "$lines" | grep -oiE 'supersed[a-z]*[[:space:]]+(by)?[[:space:]]*(adr[- ]?)?[0-9]+' | grep -oE '[0-9]+$' | sort -u)

    if [ -z "$refs" ] && [ -z "$nums" ]; then
        # Only a status that CLAIMS to be superseded owes a replacement. A record that
        # merely uses the word in its prose owes nothing.
        printf '%s' "$v" | grep -qiE '^supersed' && \
            say "SUPERSEDE $f: status is '$v' but names no replacement; a superseded record that does not say by what is a dead end."
        continue
    fi

    while IFS= read -r r; do
        [ -n "$r" ] || continue
        # Relative to the collection, as written. Taking basename() collapsed the path, so
        # a link climbing out of the directory "resolved" against a same-named record here.
        # A link that legitimately points outside still resolves, and --portable is what
        # reports that it will break on a copy: two questions, two checks.
        [ -f "$DIR/$r" ] || say "SUPERSEDE $f: link to '$r' resolves to nothing from $DIR."
    done <<EOF
$refs
EOF

    # A numeric reference can only be resolved where the scheme carries a number. Under a
    # dated or free-form scheme records cite each other by filename, so a bare number is
    # unresolvable BY DESIGN and reporting it as dangling would be a false positive on
    # every one. Worse, the first version extracted the year out of 2026-08-26-slug.md and
    # compared against that, so the check was not merely inapplicable there, it was
    # answering a different question with a straight face.
    case "$scheme" in
        numbered|prefixed)
            while IFS= read -r num; do
                [ -n "$num" ] || continue
                [ -n "$(resolve_num "$num")" ] || say "SUPERSEDE $f: reference to record $num resolves to nothing in $DIR."
            done <<EOF
$nums
EOF
            ;;
        *)
            [ -n "$nums" ] && numeric_refs_unresolvable=1
            ;;
    esac
done < "$T/statuses"

[ "$numeric_refs_unresolvable" -eq 1 ] && \
    skipped "SUPERSEDE (numeric references only): this scheme carries no number, so records cite each other by filename; bare-number references were left unchecked rather than reported as dangling."

# --- INDEX -------------------------------------------------------------------------------
# Both directions. A one-way check is the one that reads as clean while the index rots: a
# record added and never listed is invisible to anyone reading the index, and a record
# deleted while its row stays is a link to nothing.
if [ -z "$index" ]; then
    skipped "INDEX: no README.md or index.md in $DIR, so there is nothing to compare the directory against."
else
    index_links "$index" > "$T/indexed"

    while IFS= read -r f; do
        [ -n "$f" ] || continue
        b=$(basename "$f")
        grep -qxF "$b" "$T/indexed" || say "INDEX $index: $b is on disk and absent from the index."
    done <<EOF
$records
EOF

    while IFS= read -r b; do
        [ -n "$b" ] || continue
        case "$(printf '%s' "$b" | lower)" in readme.md|index.md|template.md) continue ;; esac
        [ -f "$DIR/$b" ] || say "INDEX $index: links to $b, which is not on disk."
    done < "$T/indexed"
fi

# --- PORTABLE ----------------------------------------------------------------------------
# Portability, not privacy. What breaks when a record is copied into another repo: an
# absolute path that exists on one machine, and a relative link that climbs out of the
# collection directory and lands nowhere once the directory moves.
#
# It deliberately stops there. Hostnames, instance names, IP ranges and personal identity
# are privacy-guard's list, and that list is gitignored ON PURPOSE: publishing it would
# reveal what it protects. A second token file here would be a second home for one list,
# and two homes diverge in silence. Audit those with privacy-guard's denylist instead:
#
#   grep -n -i -E -f <(grep -vE '^[[:space:]]*(#|$)' .local/privacy-denylist.txt) DIR/*.md
if [ "$PORTABLE" -eq 1 ]; then
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        while IFS= read -r hit; do
            [ -n "$hit" ] || continue
            say "PORTABLE $f:$hit"
        done < <(grep -nE '(/home/|/Users/)[^/[:space:]]+' "$f" | sed 's/$/  <- absolute path, valid only on the machine that wrote it/')
        while IFS= read -r hit; do
            [ -n "$hit" ] || continue
            say "PORTABLE $f:$hit"
        done < <(grep -nE '\]\(\.\./' "$f" | sed 's/$/  <- link climbs out of the collection, breaks when the record is copied/')
    done <<EOF
$records
EOF
    echo "note: PORTABLE covers paths and links only. Hostnames, instance names and identity are privacy-guard's denylist, not duplicated here." >&2
else
    skipped "PORTABLE: not requested; pass --portable to check what breaks when a record is copied."
fi

# --- verdict -----------------------------------------------------------------------------
# The skipped list goes out BEFORE the verdict, and always. A reader who sees only
# "OK: no violations" has no way to know how many of the eight checks were in a position to
# say anything, and that gap is what turned two silent no-ops into shipped defects here.
if [ -s "$T/skipped" ]; then
    echo "" >&2
    echo "checks that did not run on this collection:" >&2
    cat "$T/skipped" >&2
fi

if [ "$violations" -eq 0 ]; then
    echo "OK: $n records, no violations."
    exit 0
fi
echo ""
echo "$violations violation(s) in $n records."
exit 1
